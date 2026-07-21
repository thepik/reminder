#import "ReminderStore.h"

@interface ReminderStore ()
@property (nonatomic, copy) NSArray<ReminderCategory *> *categories;
@property (nonatomic, copy) NSString *currentCategoryID;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<ReminderItem *> *> *itemsByCategory;
@property (nonatomic, strong) NSURL *storageURL;
@property (nonatomic) dispatch_queue_t persistenceQueue;
- (NSString *)validatedDisplayName:(NSString *)rawDisplayName excludingCategoryID:(NSString *)excludedIdentifier;
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

- (NSString *)addCategoryWithDisplayName:(NSString *)rawDisplayName {
    NSString *displayName = [self validatedDisplayName:rawDisplayName excludingCategoryID:nil];
    if (!displayName) {
        return nil;
    }

    NSString *identifier = [NSString stringWithFormat:@"custom-%@", NSUUID.UUID.UUIDString.lowercaseString];
    ReminderCategory *category = [[ReminderCategory alloc] initWithIdentifier:identifier
                                                                  displayName:displayName
                                                                   rowActions:ReminderRowActionDelete];
    self.categories = [self.categories arrayByAddingObject:category];
    self.itemsByCategory[identifier] = [NSMutableArray array];
    [self persistAsync];
    return identifier;
}

- (BOOL)renameCategoryWithIdentifier:(NSString *)identifier displayName:(NSString *)rawDisplayName {
    ReminderCategory *existingCategory = [self categoryForIdentifier:identifier];
    NSString *displayName = [self validatedDisplayName:rawDisplayName excludingCategoryID:identifier];
    if (!existingCategory || !displayName) {
        return NO;
    }

    NSUInteger categoryIndex = [self.categories indexOfObjectIdenticalTo:existingCategory];
    if (categoryIndex == NSNotFound) {
        return NO;
    }

    ReminderCategory *renamedCategory = [[ReminderCategory alloc] initWithIdentifier:existingCategory.identifier
                                                                          displayName:displayName
                                                                           rowActions:existingCategory.rowActions];
    NSMutableArray<ReminderCategory *> *updatedCategories = [self.categories mutableCopy];
    updatedCategories[categoryIndex] = renamedCategory;
    self.categories = [updatedCategories copy];
    [self persistAsync];
    return YES;
}

- (BOOL)removeCategoryWithIdentifier:(NSString *)identifier {
    ReminderCategory *category = [self categoryForIdentifier:identifier];
    if (!category || self.categories.count <= 1) {
        return NO;
    }

    NSUInteger removedIndex = [self.categories indexOfObjectIdenticalTo:category];
    NSMutableArray<ReminderCategory *> *updatedCategories = [self.categories mutableCopy];
    [updatedCategories removeObjectAtIndex:removedIndex];
    self.categories = [updatedCategories copy];
    [self.itemsByCategory removeObjectForKey:identifier];

    if ([self.currentCategoryID isEqualToString:identifier]) {
        NSUInteger fallbackIndex = MIN(removedIndex, self.categories.count - 1);
        self.currentCategoryID = self.categories[fallbackIndex].identifier;
    }

    [self persistAsync];
    return YES;
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
    NSMutableArray *categoryDefinitions = [NSMutableArray array];
    for (ReminderCategory *category in self.categories) {
        [categoryDefinitions addObject:@{
            @"id": category.identifier,
            @"displayName": category.displayName,
            @"rowActions": @(category.rowActions)
        }];
        NSMutableArray *serialized = [NSMutableArray array];
        for (ReminderItem *item in self.itemsByCategory[category.identifier]) {
            [serialized addObject:[item dictionaryRepresentation]];
        }
        categoryItems[category.identifier] = serialized;
    }

    return @{
        @"schemaVersion": @3,
        @"categoryDefinitions": categoryDefinitions,
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
    NSArray *categoryDefinitions = root[@"categoryDefinitions"];
    if ([categoryDefinitions isKindOfClass:NSArray.class]) {
        NSMutableArray<ReminderCategory *> *loadedCategories = [NSMutableArray array];
        NSMutableSet<NSString *> *loadedIdentifiers = [NSMutableSet set];
        NSMutableSet<NSString *> *loadedNames = [NSMutableSet set];
        for (id rawDefinition in categoryDefinitions) {
            if (![rawDefinition isKindOfClass:NSDictionary.class]) {
                continue;
            }
            NSDictionary *definition = (NSDictionary *)rawDefinition;
            NSString *identifier = definition[@"id"];
            NSString *displayName = definition[@"displayName"];
            NSNumber *rowActions = definition[@"rowActions"];
            NSString *normalizedName = displayName.lowercaseString;
            if (![identifier isKindOfClass:NSString.class] || identifier.length == 0 ||
                ![displayName isKindOfClass:NSString.class] || displayName.length == 0 || displayName.length > 40 ||
                [loadedIdentifiers containsObject:identifier] || [loadedNames containsObject:normalizedName]) {
                continue;
            }

            ReminderRowAction actions = ReminderRowActionDelete;
            if ([rowActions isKindOfClass:NSNumber.class] &&
                (rowActions.unsignedIntegerValue & ReminderRowActionCopy) != 0) {
                actions |= ReminderRowActionCopy;
            }
            [loadedCategories addObject:[[ReminderCategory alloc] initWithIdentifier:identifier
                                                                         displayName:displayName
                                                                          rowActions:actions]];
            [loadedIdentifiers addObject:identifier];
            [loadedNames addObject:normalizedName];
        }
        if (loadedCategories.count > 0) {
            self.categories = [loadedCategories copy];
            self.itemsByCategory = [self emptyItemsByCategory];
            if (![self categoryForIdentifier:self.currentCategoryID]) {
                self.currentCategoryID = self.categories.firstObject.identifier;
            }
        }
    }

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

- (NSString *)validatedDisplayName:(NSString *)rawDisplayName excludingCategoryID:(NSString *)excludedIdentifier {
    if (![rawDisplayName isKindOfClass:NSString.class]) {
        return nil;
    }
    NSString *displayName = [rawDisplayName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (displayName.length == 0 || displayName.length > 40) {
        return nil;
    }
    for (ReminderCategory *category in self.categories) {
        if ([category.identifier isEqualToString:excludedIdentifier]) {
            continue;
        }
        if ([category.displayName caseInsensitiveCompare:displayName] == NSOrderedSame) {
            return nil;
        }
    }
    return displayName;
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
