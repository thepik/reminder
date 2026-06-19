#import <AppKit/AppKit.h>
#import "../Models/ReminderCategory.h"

typedef void (^ReminderCategorySelectHandler)(NSString *categoryID);

@interface CategoryTabView : NSView

@property (nonatomic, copy) ReminderCategorySelectHandler onSelectCategory;

- (instancetype)initWithCategories:(NSArray<ReminderCategory *> *)categories;
- (void)setSelectedCategoryID:(NSString *)categoryID;

@end
