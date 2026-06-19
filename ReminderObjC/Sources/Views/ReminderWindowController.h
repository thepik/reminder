#import <AppKit/AppKit.h>
#import "../Store/ReminderStore.h"

@interface ReminderWindowController : NSWindowController <NSWindowDelegate>

- (instancetype)initWithStore:(ReminderStore *)store;
- (void)showAndFocus;

@end
