#import "CategoryTabView.h"
#import "../Theme/ReminderTheme.h"

@interface CategoryTabView ()
@property (nonatomic, copy) NSArray<ReminderCategory *> *categories;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSButton *> *buttonsByCategory;
@property (nonatomic, copy) NSString *selectedCategoryID;
@end

@implementation CategoryTabView

- (instancetype)initWithCategories:(NSArray<ReminderCategory *> *)categories {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _categories = [categories copy];
        _buttonsByCategory = [NSMutableDictionary dictionary];

        self.wantsLayer = YES;
        self.layer.cornerRadius = 4.0;
        self.layer.masksToBounds = YES;

        NSStackView *stackView = [[NSStackView alloc] init];
        stackView.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        stackView.spacing = 0;
        stackView.distribution = NSStackViewDistributionFillEqually;
        stackView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:stackView];

        [NSLayoutConstraint activateConstraints:@[
            [stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [stackView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [stackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
        ]];

        for (ReminderCategory *category in categories) {
            NSButton *button = [NSButton buttonWithTitle:category.displayName target:self action:@selector(categoryPressed:)];
            button.bordered = NO;
            button.wantsLayer = YES;
            button.identifier = category.identifier;
            button.translatesAutoresizingMaskIntoConstraints = NO;
            [button.heightAnchor constraintEqualToConstant:26].active = YES;
            [self.buttonsByCategory setObject:button forKey:category.identifier];
            [stackView addArrangedSubview:button];
        }
    }
    return self;
}

- (void)setSelectedCategoryID:(NSString *)categoryID {
    _selectedCategoryID = [categoryID copy];
    [self updateButtons];
}

- (void)categoryPressed:(NSButton *)sender {
    NSString *categoryID = sender.identifier;
    if (categoryID.length == 0) {
        return;
    }
    if (self.onSelectCategory) {
        self.onSelectCategory(categoryID);
    }
}

- (void)updateButtons {
    for (ReminderCategory *category in self.categories) {
        NSButton *button = self.buttonsByCategory[category.identifier];
        BOOL selected = [category.identifier isEqualToString:self.selectedCategoryID];
        button.layer.backgroundColor = (selected ? ReminderTheme.accentColor : ReminderTheme.inactiveTabColor).CGColor;
        button.attributedTitle = [ReminderTheme buttonTitle:category.displayName
                                                      color:ReminderTheme.primaryTextColor
                                                       font:[ReminderTheme mediumFontOfSize:13]];
    }
}

@end
