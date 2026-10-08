#import <Foundation/Foundation.h>
#import "../Sources/Models/ReminderCategory.h"
#import "../Sources/Models/ReminderItem.h"
#import "../Sources/Store/ReminderStore.h"

static NSUInteger gFailures = 0;

#define AssertTrue(condition, message) \
    do { \
        if (!(condition)) { \
            gFailures++; \
            NSLog(@"FAIL: %s", message); \
        } \
    } while (0)

#define AssertEqualObjects(actual, expected, message) \
    do { \
        id actualValue = (actual); \
        id expectedValue = (expected); \
        if (![actualValue isEqual:expectedValue]) { \
            gFailures++; \
            NSLog(@"FAIL: %s\n  actual: %@\nexpected: %@", message, actualValue, expectedValue); \
        } \
    } while (0)

static NSURL *TemporaryStoreURL(void) {
    NSString *name = [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"json"];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

static ReminderStore *MakeStore(NSURL **urlOut) {
    NSURL *url = TemporaryStoreURL();
    if (urlOut != NULL) {
        *urlOut = url;
    }
    return [[ReminderStore alloc] initWithStorageURL:url];
}

static void TestDefaultCategories(void) {
    ReminderStore *store = MakeStore(NULL);
    NSArray<ReminderCategory *> *categories = store.categories;

    AssertEqualObjects([categories valueForKey:@"identifier"], (@[@"work", @"life", @"quickCommand", @"raycastCommand"]), "default category order");
    AssertEqualObjects([categories valueForKey:@"displayName"], (@[@"工作", @"生活", @"快捷命令", @"Raycast命令"]), "default category display names");
    for (ReminderCategory *category in categories) {
        AssertTrue((category.rowActions & ReminderRowActionCopy) != 0, "default category copies");
        AssertTrue((category.rowActions & ReminderRowActionDelete) != 0, "default category deletes");
    }
    AssertEqualObjects(store.currentCategoryID, @"work", "default category is work");
}

static void TestAddTrimAndCategoryIsolation(void) {
    ReminderStore *store = MakeStore(NULL);

    AssertTrue(![store addItemWithContent:@"   \n\t  "], "blank content is ignored");
    AssertTrue([store addItemWithContent:@"  work item  "], "work item saves");
    [store switchToCategory:@"life"];
    AssertTrue([store addItemWithContent:@"life item"], "life item saves");
    [store switchToCategory:@"quickCommand"];
    AssertTrue([store addItemWithContent:@" cd /tmp && ls "], "quick command saves");

    AssertEqualObjects([[store itemsForCategory:@"work"] valueForKey:@"content"], (@[@"work item"]), "work content is trimmed");
    AssertEqualObjects([[store itemsForCategory:@"life"] valueForKey:@"content"], (@[@"life item"]), "life content is isolated");
    AssertEqualObjects([[store currentItems] valueForKey:@"content"], (@[@"cd /tmp && ls"]), "current quick command content is trimmed");
}

static void TestAddRenameAndRemoveCategory(void) {
    NSURL *url = nil;
    ReminderStore *store = MakeStore(&url);

    NSString *categoryID = [store addCategoryWithDisplayName:@"  学习  "];
    AssertTrue(categoryID.length > 0, "custom category is created");
    AssertEqualObjects([store categoryForIdentifier:categoryID].displayName, @"学习", "custom category name is trimmed");
    AssertTrue(([store categoryForIdentifier:categoryID].rowActions & ReminderRowActionCopy) != 0 &&
               ([store categoryForIdentifier:categoryID].rowActions & ReminderRowActionDelete) != 0,
               "custom category copies and deletes");
    AssertTrue([store addCategoryWithDisplayName:@"学习"] == nil, "duplicate category names are rejected");

    [store switchToCategory:categoryID];
    [store addItemWithContent:@"read docs"];
    AssertTrue([store renameCategoryWithIdentifier:categoryID displayName:@"研究"], "custom category can be renamed");
    AssertEqualObjects([store categoryForIdentifier:categoryID].displayName, @"研究", "renaming preserves category identity");
    AssertEqualObjects([[store currentItems] valueForKey:@"content"], (@[@"read docs"]), "renaming preserves category items");

    [store flushSync];
    ReminderStore *reloaded = [[ReminderStore alloc] initWithStorageURL:url];
    AssertEqualObjects([reloaded categoryForIdentifier:categoryID].displayName, @"研究", "custom category name reloads");
    AssertEqualObjects([[reloaded itemsForCategory:categoryID] valueForKey:@"content"], (@[@"read docs"]), "custom category items reload");

    [reloaded switchToCategory:categoryID];
    AssertTrue([reloaded removeCategoryWithIdentifier:categoryID], "custom category can be removed");
    AssertTrue([reloaded categoryForIdentifier:categoryID] == nil, "removed category is no longer listed");
    AssertTrue(![reloaded.currentCategoryID isEqualToString:categoryID], "removing the active category selects a fallback");
    AssertTrue([reloaded itemsForCategory:categoryID].count == 0, "removing a category removes its items");
}

static void TestDeleteOnlyRemovesFromMatchingCategory(void) {
    ReminderStore *store = MakeStore(NULL);

    [store addItemWithContent:@"work"];
    NSString *workID = [store itemsForCategory:@"work"].firstObject.itemID;
    [store switchToCategory:@"life"];
    [store addItemWithContent:@"life"];

    [store deleteItemWithID:workID categoryID:@"work"];

    AssertTrue([store itemsForCategory:@"work"].count == 0, "work item removed");
    AssertEqualObjects([[store itemsForCategory:@"life"] valueForKey:@"content"], (@[@"life"]), "life item remains");
}

static void TestLegacySnapshotMigration(void) {
    NSURL *url = TemporaryStoreURL();
    NSString *legacyJSON = @"{"
        "\"schemaVersion\":1,"
        "\"work\":[{\"id\":\"w1\",\"category\":\"work\",\"content\":\"legacy work\",\"createdAt\":\"2026-06-19T00:00:00Z\"}],"
        "\"life\":[],"
        "\"quickCommands\":[{\"id\":\"q1\",\"category\":\"quickCommand\",\"content\":\"legacy command\",\"createdAt\":\"2026-06-19T00:00:01Z\"}]"
    "}";
    [legacyJSON writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];

    ReminderStore *store = [[ReminderStore alloc] initWithStorageURL:url];

    AssertEqualObjects([[store itemsForCategory:@"work"] valueForKey:@"content"], (@[@"legacy work"]), "legacy work loads");
    AssertEqualObjects([[store itemsForCategory:@"quickCommand"] valueForKey:@"content"], (@[@"legacy command"]), "legacy quick commands load");
}

static void TestDeleteOnlyCategoriesUpgradeToCopyAndDelete(void) {
    NSURL *url = TemporaryStoreURL();
    NSString *legacyJSON = @"{"
        "\"schemaVersion\":3,"
        "\"categoryDefinitions\":["
            "{\"id\":\"work\",\"displayName\":\"工作\",\"rowActions\":1},"
            "{\"id\":\"quickCommand\",\"displayName\":\"快捷命令\",\"rowActions\":3},"
            "{\"id\":\"custom-abc\",\"displayName\":\"常规命令\",\"rowActions\":1}"
        "],"
        "\"categories\":{"
            "\"work\":[{\"id\":\"w1\",\"category\":\"work\",\"content\":\"kept work\",\"createdAt\":\"2026-06-19T00:00:00Z\"}],"
            "\"quickCommand\":[{\"id\":\"q1\",\"category\":\"quickCommand\",\"content\":\"kept command\",\"createdAt\":\"2026-06-19T00:00:01Z\"}],"
            "\"custom-abc\":[{\"id\":\"c1\",\"category\":\"custom-abc\",\"content\":\"kept custom\",\"createdAt\":\"2026-06-19T00:00:02Z\"}]"
        "}"
        "}";
    [legacyJSON writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];

    ReminderStore *store = [[ReminderStore alloc] initWithStorageURL:url];

    AssertEqualObjects([store.categories valueForKey:@"identifier"],
                       (@[@"work", @"quickCommand", @"custom-abc"]),
                       "historical categories are preserved");
    for (ReminderCategory *category in store.categories) {
        AssertTrue((category.rowActions & ReminderRowActionCopy) != 0,
                   "historical category gains copy on load");
        AssertTrue((category.rowActions & ReminderRowActionDelete) != 0,
                   "historical category keeps delete on load");
    }
    AssertEqualObjects([[store itemsForCategory:@"work"] valueForKey:@"content"], (@[@"kept work"]),
                       "historical work items are preserved");
    AssertEqualObjects([[store itemsForCategory:@"custom-abc"] valueForKey:@"content"], (@[@"kept custom"]),
                       "historical custom items are preserved");
}

static void TestFlushWritesSchemaV3AndReloads(void) {
    NSURL *url = nil;
    ReminderStore *store = MakeStore(&url);
    [store addItemWithContent:@"persisted work"];
    [store switchToCategory:@"quickCommand"];
    [store addItemWithContent:@"persisted command"];
    [store flushSync];

    NSData *data = [NSData dataWithContentsOfURL:url];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    AssertEqualObjects(json[@"schemaVersion"], @3, "schema version 3 is written");
    AssertTrue([json[@"categoryDefinitions"] isKindOfClass:NSArray.class], "schema v3 has category definitions");
    AssertTrue([json[@"categories"] isKindOfClass:NSDictionary.class], "schema v3 has categories dictionary");

    ReminderStore *reloaded = [[ReminderStore alloc] initWithStorageURL:url];
    AssertEqualObjects([[reloaded itemsForCategory:@"work"] valueForKey:@"content"], (@[@"persisted work"]), "work reloads");
    AssertEqualObjects([[reloaded itemsForCategory:@"quickCommand"] valueForKey:@"content"], (@[@"persisted command"]), "quick command reloads");
}

static void TestCorruptedJSONFallsBackToEmpty(void) {
    NSURL *url = TemporaryStoreURL();
    [@"not json" writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];

    ReminderStore *store = [[ReminderStore alloc] initWithStorageURL:url];

    AssertTrue([store itemsForCategory:@"work"].count == 0, "corrupted work is empty");
    AssertTrue([store itemsForCategory:@"life"].count == 0, "corrupted life is empty");
    AssertTrue([store itemsForCategory:@"quickCommand"].count == 0, "corrupted quick command is empty");
}

int main(void) {
    @autoreleasepool {
        TestDefaultCategories();
        TestAddTrimAndCategoryIsolation();
        TestAddRenameAndRemoveCategory();
        TestDeleteOnlyRemovesFromMatchingCategory();
        TestLegacySnapshotMigration();
        TestDeleteOnlyCategoriesUpgradeToCopyAndDelete();
        TestFlushWritesSchemaV3AndReloads();
        TestCorruptedJSONFallsBackToEmpty();

        if (gFailures > 0) {
            NSLog(@"%lu test failure(s)", (unsigned long)gFailures);
            return 1;
        }

        NSLog(@"All Objective-C store tests passed");
        return 0;
    }
}
