#import <Foundation/Foundation.h>
#import "../Models/ReminderCategory.h"
#import "../Models/ReminderItem.h"

@interface ReminderStore : NSObject

@property (nonatomic, copy, readonly) NSArray<ReminderCategory *> *categories;
@property (nonatomic, copy, readonly) NSString *currentCategoryID;

- (instancetype)initWithStorageURL:(NSURL *)storageURL;
+ (NSURL *)defaultStorageURL;

- (BOOL)addItemWithContent:(NSString *)rawContent;
- (void)deleteItemWithID:(NSString *)itemID categoryID:(NSString *)categoryID;
- (NSString *)addCategoryWithDisplayName:(NSString *)rawDisplayName;
- (BOOL)renameCategoryWithIdentifier:(NSString *)identifier displayName:(NSString *)rawDisplayName;
- (BOOL)removeCategoryWithIdentifier:(NSString *)identifier;
- (BOOL)switchToCategory:(NSString *)categoryID;
- (NSArray<ReminderItem *> *)itemsForCategory:(NSString *)categoryID;
- (NSArray<ReminderItem *> *)currentItems;
- (ReminderCategory *)categoryForIdentifier:(NSString *)identifier;
- (void)flushSync;

@end
