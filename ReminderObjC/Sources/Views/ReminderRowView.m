#import "ReminderRowView.h"
#import "../Theme/ReminderTheme.h"

@interface ReminderRowView ()
@property (nonatomic, strong) ReminderItem *item;
@end

@implementation ReminderRowView

- (instancetype)initWithItem:(ReminderItem *)item category:(ReminderCategory *)category {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _item = item;

        self.wantsLayer = YES;
        self.layer.backgroundColor = ReminderTheme.cardColor.CGColor;
        self.layer.cornerRadius = 4.0;
        self.translatesAutoresizingMaskIntoConstraints = NO;

        NSTextField *label = [NSTextField labelWithString:item.content];
        label.font = [ReminderTheme regularFontOfSize:16];
        label.textColor = NSColor.whiteColor;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        label.maximumNumberOfLines = 1;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:label];

        NSButton *deleteButton = [self makeTextButton:@"删除"
                                                color:ReminderTheme.dangerColor
                                               action:@selector(deletePressed:)];
        [self addSubview:deleteButton];

        NSButton *copyButton = nil;
        if ((category.rowActions & ReminderRowActionCopy) != 0) {
            copyButton = [self makeTextButton:@"复制"
                                        color:ReminderTheme.secondaryTextColor
                                       action:@selector(copyPressed:)];
            [self addSubview:copyButton];
        }

        NSMutableArray *constraints = [NSMutableArray arrayWithArray:@[
            [self.heightAnchor constraintEqualToConstant:44],
            [label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
            [label.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [deleteButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
            [deleteButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [deleteButton.widthAnchor constraintEqualToConstant:40]
        ]];

        if (copyButton) {
            [constraints addObjectsFromArray:@[
                [copyButton.trailingAnchor constraintEqualToAnchor:deleteButton.leadingAnchor constant:-16],
                [copyButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
                [copyButton.widthAnchor constraintEqualToConstant:40],
                [label.trailingAnchor constraintLessThanOrEqualToAnchor:copyButton.leadingAnchor constant:-16]
            ]];
        } else {
            [constraints addObject:[label.trailingAnchor constraintLessThanOrEqualToAnchor:deleteButton.leadingAnchor constant:-16]];
        }

        [NSLayoutConstraint activateConstraints:constraints];
    }
    return self;
}

- (NSButton *)makeTextButton:(NSString *)title color:(NSColor *)color action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.bordered = NO;
    button.attributedTitle = [ReminderTheme buttonTitle:title
                                                  color:color
                                                   font:[ReminderTheme regularFontOfSize:16]];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

- (void)copyPressed:(id)sender {
    (void)sender;
    if (self.onCopy) {
        self.onCopy(self.item);
    }
}

- (void)deletePressed:(id)sender {
    (void)sender;
    if (self.onDelete) {
        self.onDelete(self.item);
    }
}

@end
