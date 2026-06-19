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
- (BOOL)switchToCategory:(NSString *)categoryID;
- (NSArray<ReminderItem *> *)itemsForCategory:(NSString *)categoryID;
- (NSArray<ReminderItem *> *)currentItems;
- (ReminderCategory *)categoryForIdentifier:(NSString *)identifier;
- (void)flushSync;

@end
