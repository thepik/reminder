#import "ReminderTheme.h"

@implementation ReminderTheme

+ (NSColor *)colorWithHex:(NSUInteger)hex {
    CGFloat red = ((hex >> 16) & 0xFF) / 255.0;
    CGFloat green = ((hex >> 8) & 0xFF) / 255.0;
    CGFloat blue = (hex & 0xFF) / 255.0;
    return [NSColor colorWithSRGBRed:red green:green blue:blue alpha:1.0];
}

+ (NSColor *)backgroundColor {
    return [self colorWithHex:0x24252F];
}

+ (NSColor *)cardColor {
    return [self colorWithHex:0x272D31];
}

+ (NSColor *)accentColor {
    return [self colorWithHex:0x4482F9];
}

+ (NSColor *)inactiveTabColor {
    return [self colorWithHex:0x292A35];
}

+ (NSColor *)placeholderColor {
    return [self colorWithHex:0x848484];
}

+ (NSColor *)dangerColor {
    return [self colorWithHex:0xB00000];
}

+ (NSColor *)secondaryTextColor {
    return [self colorWithHex:0xA3A3A5];
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
