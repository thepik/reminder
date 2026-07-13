#import "ReminderTheme.h"

@implementation ReminderTheme

+ (NSColor *)colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha {
    CGFloat red = ((hex >> 16) & 0xFF) / 255.0;
    CGFloat green = ((hex >> 8) & 0xFF) / 255.0;
    CGFloat blue = (hex & 0xFF) / 255.0;
    return [NSColor colorWithSRGBRed:red green:green blue:blue alpha:alpha];
}

+ (NSColor *)dynamicColorNamed:(NSString *)name light:(NSUInteger)lightHex dark:(NSUInteger)darkHex {
    return [NSColor colorWithName:name dynamicProvider:^NSColor *(NSAppearance *appearance) {
        NSAppearanceName match = [appearance bestMatchFromAppearancesWithNames:@[
            NSAppearanceNameAqua,
            NSAppearanceNameDarkAqua
        ]];
        NSUInteger hex = [match isEqualToString:NSAppearanceNameDarkAqua] ? darkHex : lightHex;
        return [self colorWithHex:hex alpha:1.0];
    }];
}

+ (NSColor *)backgroundColor {
    return [self dynamicColorNamed:@"ReminderBackground" light:0xF7F7F5 dark:0x1E1E1E];
}

+ (NSColor *)sidebarBackgroundColor {
    return [self dynamicColorNamed:@"ReminderSidebarBackground" light:0xECECEA dark:0x262626];
}

+ (NSColor *)cardColor {
    return [self dynamicColorNamed:@"ReminderCard" light:0xFFFFFF dark:0x2C2C2E];
}

+ (NSColor *)cardHoverColor {
    return [self dynamicColorNamed:@"ReminderCardHover" light:0xF2F2EF dark:0x363638];
}

+ (NSColor *)accentColor {
    return [self dynamicColorNamed:@"ReminderAccent" light:0xFFCC00 dark:0xFFD60A];
}

+ (NSColor *)accentPressedColor {
    return [self dynamicColorNamed:@"ReminderAccentPressed" light:0xE5B800 dark:0xE6C109];
}

+ (NSColor *)accentTextColor {
    return [self colorWithHex:0x332A00 alpha:1.0];
}

+ (NSColor *)inactiveTabColor {
    return NSColor.clearColor;
}

+ (NSColor *)selectedSidebarItemColor {
    return [self dynamicColorNamed:@"ReminderSidebarSelection" light:0xD8D8D5 dark:0x464648];
}

+ (NSColor *)placeholderColor {
    return [self dynamicColorNamed:@"ReminderPlaceholder" light:0x989894 dark:0x8E8E93];
}

+ (NSColor *)dangerColor {
    return [self dynamicColorNamed:@"ReminderDanger" light:0xD93C37 dark:0xFF6961];
}

+ (NSColor *)dangerHoverColor {
    return [self dynamicColorNamed:@"ReminderDangerHover" light:0xFCE8E6 dark:0x4A2B2B];
}

+ (NSColor *)secondaryTextColor {
    return [self dynamicColorNamed:@"ReminderSecondaryText" light:0x666663 dark:0xAEAEB2];
}

+ (NSColor *)tertiaryTextColor {
    return [self dynamicColorNamed:@"ReminderTertiaryText" light:0x8A8A86 dark:0x7D7D80];
}

+ (NSColor *)primaryTextColor {
    return [self dynamicColorNamed:@"ReminderPrimaryText" light:0x20201E dark:0xF2F2F7];
}

+ (NSColor *)inputBorderColor {
    return [self dynamicColorNamed:@"ReminderInputBorder" light:0xD9D9D5 dark:0x48484A];
}

+ (NSColor *)inputBackgroundColor {
    return [self dynamicColorNamed:@"ReminderInputBackground" light:0xFFFFFF dark:0x2C2C2E];
}

+ (NSColor *)separatorColor {
    return [self dynamicColorNamed:@"ReminderSeparator" light:0xD8D8D5 dark:0x3A3A3C];
}

+ (NSColor *)focusRingColor {
    return [self colorWithHex:0xFFCC00 alpha:0.48];
}

+ (NSColor *)toastBackgroundColor {
    return [self colorWithHex:0x242422 alpha:0.92];
}

+ (NSFont *)regularFontOfSize:(CGFloat)size {
    return [NSFont systemFontOfSize:size weight:NSFontWeightRegular];
}

+ (NSFont *)mediumFontOfSize:(CGFloat)size {
    return [NSFont systemFontOfSize:size weight:NSFontWeightMedium];
}

+ (NSFont *)semiboldFontOfSize:(CGFloat)size {
    return [NSFont systemFontOfSize:size weight:NSFontWeightSemibold];
}

+ (NSFont *)monospacedFontOfSize:(CGFloat)size {
    return [NSFont monospacedSystemFontOfSize:size weight:NSFontWeightRegular];
}

+ (NSAttributedString *)buttonTitle:(NSString *)title color:(NSColor *)color font:(NSFont *)font {
    return [[NSAttributedString alloc] initWithString:title attributes:@{
        NSForegroundColorAttributeName: color,
        NSFontAttributeName: font
    }];
}

@end
