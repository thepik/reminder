#import "ReminderCategory.h"

@implementation ReminderCategory

- (instancetype)initWithIdentifier:(NSString *)identifier
                       displayName:(NSString *)displayName
                        rowActions:(ReminderRowAction)rowActions {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _displayName = [displayName copy];
        _rowActions = rowActions;
    }
    return self;
}

+ (NSArray<ReminderCategory *> *)defaultCategories {
    return @[
        [[ReminderCategory alloc] initWithIdentifier:@"work"
                                        displayName:@"工作"
                                         rowActions:(ReminderRowActionDelete | ReminderRowActionCopy)],
        [[ReminderCategory alloc] initWithIdentifier:@"life"
                                        displayName:@"生活"
                                         rowActions:(ReminderRowActionDelete | ReminderRowActionCopy)],
        [[ReminderCategory alloc] initWithIdentifier:@"quickCommand"
                                        displayName:@"快捷命令"
                                         rowActions:(ReminderRowActionDelete | ReminderRowActionCopy)],
        [[ReminderCategory alloc] initWithIdentifier:@"raycastCommand"
                                        displayName:@"Raycast命令"
                                         rowActions:(ReminderRowActionDelete | ReminderRowActionCopy)]
    ];
}

@end
