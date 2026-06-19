#import <Foundation/Foundation.h>

@interface ReminderItem : NSObject

@property (nonatomic, copy, readonly) NSString *itemID;
@property (nonatomic, copy, readonly) NSString *categoryID;
@property (nonatomic, copy, readonly) NSString *content;
@property (nonatomic, strong, readonly) NSDate *createdAt;

- (instancetype)initWithItemID:(NSString *)itemID
                    categoryID:(NSString *)categoryID
                       content:(NSString *)content
                     createdAt:(NSDate *)createdAt;

+ (instancetype)itemWithCategoryID:(NSString *)categoryID content:(NSString *)content;
+ (instancetype)itemFromDictionary:(NSDictionary *)dictionary defaultCategoryID:(NSString *)defaultCategoryID;
- (NSDictionary *)dictionaryRepresentation;

@end
