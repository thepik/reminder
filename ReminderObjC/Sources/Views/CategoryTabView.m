#import "CategoryTabView.h"
#import "../Theme/ReminderTheme.h"

@interface ReminderSidebarButton : NSButton
@property (nonatomic) BOOL categorySelected;
@property (nonatomic) BOOL pointerInside;
@property (nonatomic) NSUInteger itemCount;
@property (nonatomic, copy) NSString *categoryDisplayName;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, strong) NSTrackingArea *hoverTrackingArea;
@property (nonatomic, strong) NSImageView *symbolImageView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *countLabel;
@end

@implementation ReminderSidebarButton

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.bordered = NO;
        self.title = @"";
        self.focusRingType = NSFocusRingTypeNone;
        self.wantsLayer = YES;
        self.layer.cornerRadius = 8.0;
        self.layer.masksToBounds = YES;

        self.symbolImageView = [[NSImageView alloc] init];
        self.symbolImageView.imageScaling = NSImageScaleProportionallyDown;
        self.symbolImageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.symbolImageView];

        self.titleLabel = [NSTextField labelWithString:@""];
        self.titleLabel.font = [ReminderTheme mediumFontOfSize:14];
        self.titleLabel.textColor = ReminderTheme.primaryTextColor;
        self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.titleLabel];

        self.countLabel = [NSTextField labelWithString:@"0"];
        self.countLabel.font = [ReminderTheme regularFontOfSize:12];
        self.countLabel.textColor = ReminderTheme.tertiaryTextColor;
        self.countLabel.alignment = NSTextAlignmentRight;
        self.countLabel.accessibilityElement = NO;
        self.countLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.countLabel];
        [NSLayoutConstraint activateConstraints:@[
            [self.symbolImageView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [self.symbolImageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.symbolImageView.widthAnchor constraintEqualToConstant:18],
            [self.symbolImageView.heightAnchor constraintEqualToConstant:18],
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.symbolImageView.trailingAnchor constant:10],
            [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.countLabel.leadingAnchor constant:-8],
            [self.countLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
            [self.countLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.countLabel.widthAnchor constraintEqualToConstant:34]
        ]];
        [self updateVisualState];
    }
    return self;
}

- (void)updateTrackingAreas {
    if (self.hoverTrackingArea) {
        [self removeTrackingArea:self.hoverTrackingArea];
    }
    self.hoverTrackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                          options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect)
                                                            owner:self
                                                         userInfo:nil];
    [self addTrackingArea:self.hoverTrackingArea];
    [super updateTrackingAreas];
}

- (void)mouseEntered:(NSEvent *)event {
    (void)event;
    self.pointerInside = YES;
    [self updateVisualState];
}

- (void)mouseExited:(NSEvent *)event {
    (void)event;
    self.pointerInside = NO;
    [self updateVisualState];
}

- (void)highlight:(BOOL)flag {
    [super highlight:flag];
    [self updateVisualState];
}

- (void)setCategorySelected:(BOOL)categorySelected {
    _categorySelected = categorySelected;
    [self updateVisualState];
}

- (void)setItemCount:(NSUInteger)itemCount {
    _itemCount = itemCount;
    [self updateTitle];
}

- (void)setCategoryDisplayName:(NSString *)categoryDisplayName {
    _categoryDisplayName = [categoryDisplayName copy];
    [self updateTitle];
}

- (void)setSymbolName:(NSString *)symbolName {
    _symbolName = [symbolName copy];
    [self updateTitle];
}

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self updateVisualState];
}

- (BOOL)becomeFirstResponder {
    BOOL becameFirstResponder = [super becomeFirstResponder];
    if (becameFirstResponder) {
        [self updateVisualState];
    }
    return becameFirstResponder;
}

- (BOOL)resignFirstResponder {
    BOOL resignedFirstResponder = [super resignFirstResponder];
    if (resignedFirstResponder) {
        [self updateVisualState];
    }
    return resignedFirstResponder;
}

- (void)updateVisualState {
    NSColor *backgroundColor = NSColor.clearColor;
    if (self.categorySelected) {
        backgroundColor = ReminderTheme.selectedSidebarItemColor;
    } else if (self.isHighlighted || self.pointerInside) {
        backgroundColor = [ReminderTheme.selectedSidebarItemColor colorWithAlphaComponent:0.52];
    }
    self.layer.backgroundColor = backgroundColor.CGColor;
    BOOL focused = self.window.firstResponder == self;
    self.layer.borderColor = (focused ? ReminderTheme.focusRingColor : NSColor.clearColor).CGColor;
    self.layer.borderWidth = focused ? 2.0 : 0.0;
    self.alphaValue = self.isHighlighted ? 0.72 : 1.0;
    [self updateTitle];
}

- (void)updateTitle {
    NSString *countText = [NSString stringWithFormat:@"%lu", (unsigned long)self.itemCount];
    self.countLabel.stringValue = countText;
    self.countLabel.textColor = self.categorySelected ? ReminderTheme.secondaryTextColor : ReminderTheme.tertiaryTextColor;
    self.titleLabel.stringValue = self.categoryDisplayName ?: @"";
    self.titleLabel.textColor = ReminderTheme.primaryTextColor;

    NSImage *symbol = [NSImage imageWithSystemSymbolName:self.symbolName ?: @"note.text" accessibilityDescription:nil];
    NSColor *symbolColor = self.categorySelected ? ReminderTheme.accentPressedColor : ReminderTheme.secondaryTextColor;
    NSImageSymbolConfiguration *configuration = [NSImageSymbolConfiguration configurationWithHierarchicalColor:symbolColor];
    self.symbolImageView.image = [symbol imageWithSymbolConfiguration:configuration];
    self.toolTip = [NSString stringWithFormat:@"%@，%@ 条", self.categoryDisplayName ?: @"", countText];
    self.accessibilityLabel = self.categoryDisplayName ?: @"";
    self.accessibilityValue = self.categorySelected
        ? [NSString stringWithFormat:@"已选择，%@ 条", countText]
        : [NSString stringWithFormat:@"%@ 条", countText];
}

@end

@interface CategoryTabView ()
@property (nonatomic, copy) NSArray<ReminderCategory *> *categories;
@property (nonatomic, strong) NSMutableDictionary<NSString *, ReminderSidebarButton *> *buttonsByCategory;
@property (nonatomic, copy) NSString *selectedCategoryID;
@end

@implementation CategoryTabView

- (instancetype)initWithCategories:(NSArray<ReminderCategory *> *)categories {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _categories = [categories copy];
        _buttonsByCategory = [NSMutableDictionary dictionary];

        self.translatesAutoresizingMaskIntoConstraints = NO;

        NSTextField *appTitle = [NSTextField labelWithString:@"Reminder"];
        appTitle.font = [ReminderTheme semiboldFontOfSize:22];
        appTitle.textColor = ReminderTheme.primaryTextColor;
        appTitle.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:appTitle];

        NSTextField *sectionTitle = [NSTextField labelWithString:@"文件夹"];
        sectionTitle.font = [ReminderTheme semiboldFontOfSize:11];
        sectionTitle.textColor = ReminderTheme.tertiaryTextColor;
        sectionTitle.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:sectionTitle];

        NSStackView *stackView = [[NSStackView alloc] init];
        stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
        stackView.spacing = 4;
        stackView.alignment = NSLayoutAttributeLeading;
        stackView.distribution = NSStackViewDistributionFill;
        stackView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:stackView];

        [NSLayoutConstraint activateConstraints:@[
            [appTitle.topAnchor constraintEqualToAnchor:self.topAnchor constant:58],
            [appTitle.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
            [appTitle.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-16],

            [sectionTitle.topAnchor constraintEqualToAnchor:appTitle.bottomAnchor constant:28],
            [sectionTitle.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:22],

            [stackView.topAnchor constraintEqualToAnchor:sectionTitle.bottomAnchor constant:8],
            [stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
            [stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10]
        ]];

        for (ReminderCategory *category in categories) {
            ReminderSidebarButton *button = [[ReminderSidebarButton alloc] initWithFrame:NSZeroRect];
            button.categoryDisplayName = category.displayName;
            button.target = self;
            button.action = @selector(categoryPressed:);
            button.identifier = category.identifier;
            button.symbolName = [self symbolNameForCategoryID:category.identifier];
            button.translatesAutoresizingMaskIntoConstraints = NO;
            [stackView addArrangedSubview:button];
            [button.heightAnchor constraintEqualToConstant:36].active = YES;
            [button.widthAnchor constraintEqualToAnchor:stackView.widthAnchor].active = YES;
            [self.buttonsByCategory setObject:button forKey:category.identifier];
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

- (NSString *)symbolNameForCategoryID:(NSString *)categoryID {
    if ([categoryID isEqualToString:@"work"]) {
        return @"briefcase.fill";
    }
    if ([categoryID isEqualToString:@"life"]) {
        return @"house.fill";
    }
    return @"terminal.fill";
}

- (void)updateItemCounts:(NSDictionary<NSString *,NSNumber *> *)itemCounts {
    for (ReminderCategory *category in self.categories) {
        ReminderSidebarButton *button = self.buttonsByCategory[category.identifier];
        button.itemCount = [itemCounts[category.identifier] unsignedIntegerValue];
    }
}

- (void)updateButtons {
    for (ReminderCategory *category in self.categories) {
        ReminderSidebarButton *button = self.buttonsByCategory[category.identifier];
        BOOL selected = [category.identifier isEqualToString:self.selectedCategoryID];
        button.categorySelected = selected;
    }
}

@end
