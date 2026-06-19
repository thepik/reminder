#import "ReminderStore.h"

@interface ReminderStore ()
@property (nonatomic, copy) NSArray<ReminderCategory *> *categories;
@property (nonatomic, copy) NSString *currentCategoryID;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<ReminderItem *> *> *itemsByCategory;
@property (nonatomic, strong) NSURL *storageURL;
@property (nonatomic) dispatch_queue_t persistenceQueue;
@end

@implementation ReminderStore

- (instancetype)initWithStorageURL:(NSURL *)storageURL {
    self = [super init];
    if (self) {
        _categories = [ReminderCategory defaultCategories];
        _currentCategoryID = @"work";
        _storageURL = storageURL;
        _persistenceQueue = dispatch_queue_create("com.thepik.ReminderObjC.persistence", DISPATCH_QUEUE_SERIAL);
        _itemsByCategory = [self emptyItemsByCategory];
        [self loadFromDisk];
    }
    return self;
}

+ (NSURL *)defaultStorageURL {
    NSURL *supportURL = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory
                                                             inDomain:NSUserDomainMask
                                                    appropriateForURL:nil
                                                               create:YES
                                                                error:nil];
    if (!supportURL) {
        supportURL = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"]];
    }
    return [[supportURL URLByAppendingPathComponent:@"Reminder" isDirectory:YES] URLByAppendingPathComponent:@"tasks.json"];
}

- (NSMutableDictionary<NSString *, NSMutableArray<ReminderItem *> *> *)emptyItemsByCategory {
    NSMutableDictionary *items = [NSMutableDictionary dictionary];
    for (ReminderCategory *category in self.categories) {
        items[category.identifier] = [NSMutableArray array];
    }
    return items;
}

- (BOOL)addItemWithContent:(NSString *)rawContent {
    NSString *content = [rawContent stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (content.length == 0) {
        return NO;
    }

    ReminderItem *item = [ReminderItem itemWithCategoryID:self.currentCategoryID content:content];
    NSMutableArray *items = self.itemsByCategory[self.currentCategoryID];
    if (!items) {
        items = [NSMutableArray array];
        self.itemsByCategory[self.currentCategoryID] = items;
    }
    [items insertObject:item atIndex:0];
    [self persistAsync];
    return YES;
}

- (void)deleteItemWithID:(NSString *)itemID categoryID:(NSString *)categoryID {
    NSMutableArray<ReminderItem *> *items = self.itemsByCategory[categoryID];
    if (!items) {
        return;
    }

    NSIndexSet *matches = [items indexesOfObjectsPassingTest:^BOOL(ReminderItem *item, NSUInteger idx, BOOL *stop) {
        (void)idx;
        (void)stop;
        return [item.itemID isEqualToString:itemID];
    }];
    if (matches.count == 0) {
        return;
    }

    [items removeObjectsAtIndexes:matches];
    [self persistAsync];
}

- (BOOL)switchToCategory:(NSString *)categoryID {
    if (![self categoryForIdentifier:categoryID]) {
        return NO;
    }
    self.currentCategoryID = categoryID;
    return YES;
}

- (NSArray<ReminderItem *> *)itemsForCategory:(NSString *)categoryID {
    return [self.itemsByCategory[categoryID] copy] ?: @[];
}

- (NSArray<ReminderItem *> *)currentItems {
    return [self itemsForCategory:self.currentCategoryID];
}

- (ReminderCategory *)categoryForIdentifier:(NSString *)identifier {
    for (ReminderCategory *category in self.categories) {
        if ([category.identifier isEqualToString:identifier]) {
            return category;
        }
    }
    return nil;
}

- (void)flushSync {
    NSDictionary *snapshot = [self snapshotDictionary];
    NSURL *url = self.storageURL;
    dispatch_sync(self.persistenceQueue, ^{
        [ReminderStore writeSnapshot:snapshot toURL:url];
    });
}

- (void)persistAsync {
    NSDictionary *snapshot = [self snapshotDictionary];
    NSURL *url = self.storageURL;
    dispatch_async(self.persistenceQueue, ^{
        [ReminderStore writeSnapshot:snapshot toURL:url];
    });
}

- (NSDictionary *)snapshotDictionary {
    NSMutableDictionary *categoryItems = [NSMutableDictionary dictionary];
    for (ReminderCategory *category in self.categories) {
        NSMutableArray *serialized = [NSMutableArray array];
        for (ReminderItem *item in self.itemsByCategory[category.identifier]) {
            [serialized addObject:[item dictionaryRepresentation]];
        }
        categoryItems[category.identifier] = serialized;
    }

    return @{
        @"schemaVersion": @2,
        @"categories": categoryItems
    };
}

- (void)loadFromDisk {
    NSData *data = [NSData dataWithContentsOfURL:self.storageURL];
    if (!data) {
        return;
    }

    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![json isKindOfClass:NSDictionary.class]) {
        NSLog(@"Reminder failed to read tasks.json: %@", error);
        return;
    }

    NSDictionary *root = (NSDictionary *)json;
    NSDictionary *categoriesJSON = nil;
    if ([root[@"categories"] isKindOfClass:NSDictionary.class]) {
        categoriesJSON = root[@"categories"];
    }

    for (ReminderCategory *category in self.categories) {
        NSArray *rawItems = nil;
        if (categoriesJSON) {
            rawItems = categoriesJSON[category.identifier];
        } else if ([category.identifier isEqualToString:@"quickCommand"]) {
            rawItems = root[@"quickCommands"];
        } else {
            rawItems = root[category.identifier];
        }

        if (![rawItems isKindOfClass:NSArray.class]) {
            continue;
        }

        NSMutableArray *items = self.itemsByCategory[category.identifier];
        [items removeAllObjects];
        for (NSDictionary *itemJSON in rawItems) {
            ReminderItem *item = [ReminderItem itemFromDictionary:itemJSON defaultCategoryID:category.identifier];
            if (item) {
                [items addObject:item];
            }
        }
    }
}

+ (void)writeSnapshot:(NSDictionary *)snapshot toURL:(NSURL *)url {
    NSError *error = nil;
    [NSFileManager.defaultManager createDirectoryAtURL:url.URLByDeletingLastPathComponent
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:&error];
    if (error) {
        NSLog(@"Reminder failed to create storage directory: %@", error);
        return;
    }

    NSData *data = [NSJSONSerialization dataWithJSONObject:snapshot
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:&error];
    if (error || !data) {
        NSLog(@"Reminder failed to encode tasks.json: %@", error);
        return;
    }

    NSURL *temporaryURL = [url.URLByDeletingLastPathComponent URLByAppendingPathComponent:[NSString stringWithFormat:@".%@.tmp", NSUUID.UUID.UUIDString]];
    if (![data writeToURL:temporaryURL options:NSDataWritingAtomic error:&error]) {
        NSLog(@"Reminder failed to write temporary tasks.json: %@", error);
        return;
    }

    if ([NSFileManager.defaultManager fileExistsAtPath:url.path]) {
        [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    }
    if (![NSFileManager.defaultManager moveItemAtURL:temporaryURL toURL:url error:&error]) {
        NSLog(@"Reminder failed to replace tasks.json: %@", error);
        [NSFileManager.defaultManager removeItemAtURL:temporaryURL error:nil];
    }
}

@end
