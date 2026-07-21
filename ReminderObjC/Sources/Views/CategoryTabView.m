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

@interface ReminderSidebarDocumentView : NSView
@end

@implementation ReminderSidebarDocumentView

- (BOOL)isFlipped {
    return YES;
}

@end

@interface CategoryTabView ()
@property (nonatomic, copy) NSArray<ReminderCategory *> *categories;
@property (nonatomic, strong) NSMutableDictionary<NSString *, ReminderSidebarButton *> *buttonsByCategory;
@property (nonatomic, copy) NSString *selectedCategoryID;
@property (nonatomic, strong) NSStackView *categoryStackView;
@property (nonatomic, strong) NSButton *addCategoryButton;
@end

@implementation CategoryTabView

- (instancetype)initWithCategories:(NSArray<ReminderCategory *> *)categories {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
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

        NSScrollView *categoryScrollView = [[NSScrollView alloc] init];
        categoryScrollView.drawsBackground = NO;
        categoryScrollView.borderType = NSNoBorder;
        categoryScrollView.hasVerticalScroller = YES;
        categoryScrollView.autohidesScrollers = YES;
        categoryScrollView.scrollerStyle = NSScrollerStyleOverlay;
        categoryScrollView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:categoryScrollView];

        ReminderSidebarDocumentView *documentView = [[ReminderSidebarDocumentView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        documentView.translatesAutoresizingMaskIntoConstraints = NO;
        categoryScrollView.documentView = documentView;

        self.categoryStackView = [[NSStackView alloc] init];
        self.categoryStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
        self.categoryStackView.spacing = 4;
        self.categoryStackView.alignment = NSLayoutAttributeLeading;
        self.categoryStackView.distribution = NSStackViewDistributionFill;
        self.categoryStackView.translatesAutoresizingMaskIntoConstraints = NO;
        [documentView addSubview:self.categoryStackView];

        self.addCategoryButton = [NSButton buttonWithTitle:@"新建栏目" target:self action:@selector(addCategoryPressed:)];
        self.addCategoryButton.bordered = NO;
        self.addCategoryButton.font = [ReminderTheme mediumFontOfSize:13];
        self.addCategoryButton.contentTintColor = ReminderTheme.secondaryTextColor;
        self.addCategoryButton.image = [NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:@"新建栏目"];
        self.addCategoryButton.imagePosition = NSImageLeft;
        self.addCategoryButton.alignment = NSTextAlignmentLeft;
        self.addCategoryButton.toolTip = @"新建栏目";
        self.addCategoryButton.accessibilityLabel = @"新建栏目";
        self.addCategoryButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.addCategoryButton];

        [NSLayoutConstraint activateConstraints:@[
            [appTitle.topAnchor constraintEqualToAnchor:self.topAnchor constant:58],
            [appTitle.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
            [appTitle.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-16],

            [sectionTitle.topAnchor constraintEqualToAnchor:appTitle.bottomAnchor constant:28],
            [sectionTitle.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:22],

            [categoryScrollView.topAnchor constraintEqualToAnchor:sectionTitle.bottomAnchor constant:8],
            [categoryScrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [categoryScrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [categoryScrollView.bottomAnchor constraintEqualToAnchor:self.addCategoryButton.topAnchor constant:-8],

            [documentView.leadingAnchor constraintEqualToAnchor:categoryScrollView.contentView.leadingAnchor],
            [documentView.trailingAnchor constraintEqualToAnchor:categoryScrollView.contentView.trailingAnchor],
            [documentView.topAnchor constraintEqualToAnchor:categoryScrollView.contentView.topAnchor],
            [documentView.widthAnchor constraintEqualToAnchor:categoryScrollView.contentView.widthAnchor],
            [documentView.heightAnchor constraintGreaterThanOrEqualToAnchor:categoryScrollView.contentView.heightAnchor],

            [self.categoryStackView.topAnchor constraintEqualToAnchor:documentView.topAnchor],
            [self.categoryStackView.leadingAnchor constraintEqualToAnchor:documentView.leadingAnchor constant:10],
            [self.categoryStackView.trailingAnchor constraintEqualToAnchor:documentView.trailingAnchor constant:-10],
            [self.categoryStackView.bottomAnchor constraintLessThanOrEqualToAnchor:documentView.bottomAnchor constant:-8],

            [self.addCategoryButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18],
            [self.addCategoryButton.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-16],
            [self.addCategoryButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-18],
            [self.addCategoryButton.heightAnchor constraintEqualToConstant:30]
        ]];

        [self setCategories:categories];
    }
    return self;
}

- (void)setCategories:(NSArray<ReminderCategory *> *)categories {
    _categories = [categories copy];

    NSArray<NSView *> *existingButtons = [self.categoryStackView.arrangedSubviews copy];
    for (NSView *button in existingButtons) {
        [self.categoryStackView removeArrangedSubview:button];
        [button removeFromSuperview];
    }
    [self.buttonsByCategory removeAllObjects];

    for (ReminderCategory *category in self.categories) {
        ReminderSidebarButton *button = [[ReminderSidebarButton alloc] initWithFrame:NSZeroRect];
        button.categoryDisplayName = category.displayName;
        button.target = self;
        button.action = @selector(categoryPressed:);
        button.identifier = category.identifier;
        button.symbolName = [self symbolNameForCategoryID:category.identifier];
        button.menu = [self contextMenuForCategory:category];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [self.categoryStackView addArrangedSubview:button];
        [button.heightAnchor constraintEqualToConstant:36].active = YES;
        [button.widthAnchor constraintEqualToAnchor:self.categoryStackView.widthAnchor].active = YES;
        self.buttonsByCategory[category.identifier] = button;
    }
    [self updateButtons];
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

- (void)addCategoryPressed:(id)sender {
    (void)sender;
    if (self.onAddCategory) {
        self.onAddCategory();
    }
}

- (NSMenu *)contextMenuForCategory:(ReminderCategory *)category {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:category.displayName];
    menu.autoenablesItems = NO;

    NSMenuItem *renameItem = [[NSMenuItem alloc] initWithTitle:@"重命名…"
                                                       action:@selector(renameCategoryPressed:)
                                                keyEquivalent:@""];
    renameItem.target = self;
    renameItem.representedObject = category.identifier;
    [menu addItem:renameItem];

    NSMenuItem *removeItem = [[NSMenuItem alloc] initWithTitle:@"移除…"
                                                       action:@selector(removeCategoryPressed:)
                                                keyEquivalent:@""];
    removeItem.target = self;
    removeItem.representedObject = category.identifier;
    removeItem.enabled = self.categories.count > 1;
    [menu addItem:removeItem];
    return menu;
}

- (void)renameCategoryPressed:(NSMenuItem *)sender {
    NSString *categoryID = sender.representedObject;
    if (categoryID.length > 0 && self.onRenameCategory) {
        self.onRenameCategory(categoryID);
    }
}

- (void)removeCategoryPressed:(NSMenuItem *)sender {
    NSString *categoryID = sender.representedObject;
    if (categoryID.length > 0 && self.onRemoveCategory) {
        self.onRemoveCategory(categoryID);
    }
}

- (NSString *)symbolNameForCategoryID:(NSString *)categoryID {
    if ([categoryID isEqualToString:@"work"]) {
        return @"briefcase.fill";
    }
    if ([categoryID isEqualToString:@"life"]) {
        return @"house.fill";
    }
    if ([categoryID isEqualToString:@"quickCommand"] || [categoryID isEqualToString:@"raycastCommand"]) {
        return @"terminal.fill";
    }
    return @"folder.fill";
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
