#import <AppKit/AppKit.h>
#import "../Models/ReminderCategory.h"

typedef void (^ReminderCategorySelectHandler)(NSString *categoryID);
typedef void (^ReminderCategoryAddHandler)(void);
typedef void (^ReminderCategoryActionHandler)(NSString *categoryID);

@interface CategoryTabView : NSView

@property (nonatomic, copy) ReminderCategorySelectHandler onSelectCategory;
@property (nonatomic, copy) ReminderCategoryAddHandler onAddCategory;
@property (nonatomic, copy) ReminderCategoryActionHandler onRenameCategory;
@property (nonatomic, copy) ReminderCategoryActionHandler onRemoveCategory;

- (instancetype)initWithCategories:(NSArray<ReminderCategory *> *)categories;
- (void)setCategories:(NSArray<ReminderCategory *> *)categories;
- (void)setSelectedCategoryID:(NSString *)categoryID;
- (void)updateItemCounts:(NSDictionary<NSString *, NSNumber *> *)itemCounts;

@end
