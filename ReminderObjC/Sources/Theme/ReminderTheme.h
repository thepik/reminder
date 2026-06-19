#import <AppKit/AppKit.h>

@interface ReminderTheme : NSObject

+ (NSColor *)backgroundColor;
+ (NSColor *)cardColor;
+ (NSColor *)accentColor;
+ (NSColor *)inactiveTabColor;
+ (NSColor *)placeholderColor;
+ (NSColor *)dangerColor;
+ (NSColor *)secondaryTextColor;
+ (NSFont *)regularFontOfSize:(CGFloat)size;
+ (NSFont *)mediumFontOfSize:(CGFloat)size;
+ (NSAttributedString *)buttonTitle:(NSString *)title color:(NSColor *)color font:(NSFont *)font;

@end
