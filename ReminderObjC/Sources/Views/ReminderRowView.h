#import <AppKit/AppKit.h>
#import "../Models/ReminderCategory.h"
#import "../Models/ReminderItem.h"

typedef void (^ReminderRowHandler)(ReminderItem *item);

@interface ReminderRowView : NSView

@property (nonatomic, copy) ReminderRowHandler onCopy;
@property (nonatomic, copy) ReminderRowHandler onDelete;

- (instancetype)initWithItem:(ReminderItem *)item category:(ReminderCategory *)category;

@end
