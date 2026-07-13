#import <AppKit/AppKit.h>

typedef void (^ReminderInputSaveHandler)(NSString *text);

@interface InputBarView : NSView <NSTextViewDelegate>

@property (nonatomic, copy) ReminderInputSaveHandler onSave;

- (void)focusInput;
- (void)clearInput;
- (void)setCategoryDisplayName:(NSString *)displayName;

@end
