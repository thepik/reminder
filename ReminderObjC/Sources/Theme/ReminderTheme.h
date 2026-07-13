#import <AppKit/AppKit.h>

@interface ReminderTheme : NSObject

+ (NSColor *)backgroundColor;
+ (NSColor *)sidebarBackgroundColor;
+ (NSColor *)cardColor;
+ (NSColor *)cardHoverColor;
+ (NSColor *)accentColor;
+ (NSColor *)accentPressedColor;
+ (NSColor *)accentTextColor;
+ (NSColor *)inactiveTabColor;
+ (NSColor *)selectedSidebarItemColor;
+ (NSColor *)placeholderColor;
+ (NSColor *)dangerColor;
+ (NSColor *)dangerHoverColor;
+ (NSColor *)secondaryTextColor;
+ (NSColor *)tertiaryTextColor;
+ (NSColor *)primaryTextColor;
+ (NSColor *)toastBackgroundColor;
+ (NSColor *)inputBorderColor;
+ (NSColor *)inputBackgroundColor;
+ (NSColor *)separatorColor;
+ (NSColor *)focusRingColor;
+ (NSFont *)regularFontOfSize:(CGFloat)size;
+ (NSFont *)mediumFontOfSize:(CGFloat)size;
+ (NSFont *)semiboldFontOfSize:(CGFloat)size;
+ (NSFont *)monospacedFontOfSize:(CGFloat)size;
+ (NSAttributedString *)buttonTitle:(NSString *)title color:(NSColor *)color font:(NSFont *)font;

@end
