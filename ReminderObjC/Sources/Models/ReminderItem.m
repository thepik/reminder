#import "ReminderItem.h"

static NSISO8601DateFormatter *ReminderDateFormatter(void) {
    static NSISO8601DateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    return formatter;
}

@implementation ReminderItem

- (instancetype)initWithItemID:(NSString *)itemID
                    categoryID:(NSString *)categoryID
                       content:(NSString *)content
                     createdAt:(NSDate *)createdAt {
    self = [super init];
    if (self) {
        _itemID = [itemID copy];
        _categoryID = [categoryID copy];
        _content = [content copy];
        _createdAt = createdAt;
    }
    return self;
}

+ (instancetype)itemWithCategoryID:(NSString *)categoryID content:(NSString *)content {
    return [[ReminderItem alloc] initWithItemID:NSUUID.UUID.UUIDString
                                    categoryID:categoryID
                                       content:content
                                     createdAt:[NSDate date]];
}

+ (instancetype)itemFromDictionary:(NSDictionary *)dictionary defaultCategoryID:(NSString *)defaultCategoryID {
    if (![dictionary isKindOfClass:NSDictionary.class]) {
        return nil;
    }

    NSString *content = dictionary[@"content"];
    if (![content isKindOfClass:NSString.class] || content.length == 0) {
        return nil;
    }

    NSString *itemID = dictionary[@"itemID"];
    if (![itemID isKindOfClass:NSString.class]) {
        itemID = dictionary[@"id"];
    }
    if (![itemID isKindOfClass:NSString.class] || itemID.length == 0) {
        itemID = NSUUID.UUID.UUIDString;
    }

    NSString *categoryID = dictionary[@"categoryID"];
    if (![categoryID isKindOfClass:NSString.class]) {
        categoryID = dictionary[@"category"];
    }
    if (![categoryID isKindOfClass:NSString.class] || categoryID.length == 0) {
        categoryID = defaultCategoryID;
    }

    NSDate *createdAt = nil;
    NSString *dateString = dictionary[@"createdAt"];
    if ([dateString isKindOfClass:NSString.class]) {
        createdAt = [ReminderDateFormatter() dateFromString:dateString];
    }
    if (!createdAt) {
        createdAt = [NSDate date];
    }

    return [[ReminderItem alloc] initWithItemID:itemID
                                    categoryID:categoryID
                                       content:content
                                     createdAt:createdAt];
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"id": self.itemID,
        @"category": self.categoryID,
        @"content": self.content,
        @"createdAt": [ReminderDateFormatter() stringFromDate:self.createdAt]
    };
}

@end
