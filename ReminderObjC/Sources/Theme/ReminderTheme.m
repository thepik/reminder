#import "ReminderTheme.h"

@implementation ReminderTheme

+ (NSColor *)colorWithHex:(NSUInteger)hex {
    CGFloat red = ((hex >> 16) & 0xFF) / 255.0;
    CGFloat green = ((hex >> 8) & 0xFF) / 255.0;
    CGFloat blue = (hex & 0xFF) / 255.0;
    return [NSColor colorWithSRGBRed:red green:green blue:blue alpha:1.0];
}

+ (NSColor *)backgroundColor {
    return [self colorWithHex:0x1E1E22];
}

+ (NSColor *)cardColor {
    return [self colorWithHex:0x2A2A30];
}

+ (NSColor *)accentColor {
    return [self colorWithHex:0x5B8DEF];
}

+ (NSColor *)inactiveTabColor {
    return [self colorWithHex:0x26262C];
}

+ (NSColor *)placeholderColor {
    return [self colorWithHex:0x6B6B73];
}

+ (NSColor *)dangerColor {
    return [self colorWithHex:0xE5484D];
}

+ (NSColor *)secondaryTextColor {
    return [self colorWithHex:0x9A9AA2];
}

+ (NSColor *)primaryTextColor {
    return [self colorWithHex:0xE8E8EC];
}

+ (NSColor *)inputBorderColor {
    return [self colorWithHex:0x3A3A42];
}

+ (NSColor *)toastBackgroundColor {
    return [NSColor colorWithSRGBRed:0.109 green:0.109 blue:0.125 alpha:0.92];
}

+ (NSFont *)regularFontOfSize:(CGFloat)size {
    return [NSFont systemFontOfSize:size weight:NSFontWeightRegular];
}

+ (NSFont *)mediumFontOfSize:(CGFloat)size {
    return [NSFont systemFontOfSize:size weight:NSFontWeightMedium];
}

+ (NSAttributedString *)buttonTitle:(NSString *)title color:(NSColor *)color font:(NSFont *)font {
    return [[NSAttributedString alloc] initWithString:title attributes:@{
        NSForegroundColorAttributeName: color,
        NSFontAttributeName: font
    }];
}

@end
