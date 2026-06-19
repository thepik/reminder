#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, ReminderRowAction) {
    ReminderRowActionDelete = 1 << 0,
    ReminderRowActionCopy = 1 << 1
};

@interface ReminderCategory : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *displayName;
@property (nonatomic, readonly) ReminderRowAction rowActions;

- (instancetype)initWithIdentifier:(NSString *)identifier
                       displayName:(NSString *)displayName
                        rowActions:(ReminderRowAction)rowActions;

+ (NSArray<ReminderCategory *> *)defaultCategories;

@end
