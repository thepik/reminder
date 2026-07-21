#import "ReminderWindowController.h"
#import "CategoryTabView.h"
#import "InputBarView.h"
#import "ReminderRowView.h"
#import "../Theme/ReminderTheme.h"

@interface ReminderFlippedView : NSView
@end

@implementation ReminderFlippedView

- (BOOL)isFlipped {
    return YES;
}

@end

@interface ReminderBackgroundView : NSView
@end

@implementation ReminderBackgroundView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        [self updateBackground];
    }
    return self;
}

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self updateBackground];
}

- (void)updateBackground {
    self.layer.backgroundColor = ReminderTheme.backgroundColor.CGColor;
}

@end


@interface ReminderSeparatorView : NSView
@end

@implementation ReminderSeparatorView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        [self updateSeparator];
    }
    return self;
}

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self updateSeparator];
}

- (void)updateSeparator {
    self.layer.backgroundColor = ReminderTheme.separatorColor.CGColor;
}

@end

@interface ReminderToastTextFieldCell : NSTextFieldCell
@end

@implementation ReminderToastTextFieldCell

- (NSRect)drawingRectForBounds:(NSRect)rect {
    NSRect drawingRect = [super drawingRectForBounds:rect];
    NSSize textSize = [self.attributedStringValue boundingRectWithSize:NSMakeSize(NSWidth(rect), CGFLOAT_MAX)
                                                               options:NSStringDrawingUsesLineFragmentOrigin].size;
    CGFloat textHeight = ceil(textSize.height);
    if (textHeight <= 0) {
        textHeight = NSHeight(drawingRect);
    }

    drawingRect.origin.y = NSMinY(rect) + floor((NSHeight(rect) - textHeight) / 2.0);
    drawingRect.size.height = textHeight;
    return drawingRect;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [super drawInteriorWithFrame:[self drawingRectForBounds:cellFrame] inView:controlView];
}

@end

@interface ReminderWindowController ()
@property (nonatomic, strong) ReminderStore *store;
@property (nonatomic, strong) CategoryTabView *tabView;
@property (nonatomic, strong) NSView *mainView;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSView *documentView;
@property (nonatomic, strong) NSStackView *stackView;
@property (nonatomic, strong) InputBarView *inputBar;
@property (nonatomic, strong) NSTextField *categoryTitleLabel;
@property (nonatomic, strong) NSTextField *itemCountLabel;
@property (nonatomic, strong) NSView *emptyStateView;
@property (nonatomic, strong) NSTextField *emptyStateDescriptionLabel;
@property (nonatomic, strong) NSTextField *successToastLabel;
@property (nonatomic, strong) NSTimer *successToastTimer;
@end

@implementation ReminderWindowController

- (instancetype)initWithStore:(ReminderStore *)store {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1280, 800)
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self = [super initWithWindow:window];
    if (self) {
        _store = store;
        window.title = @"备忘录";
        window.titleVisibility = NSWindowTitleHidden;
        window.titlebarAppearsTransparent = YES;
        window.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
        window.movableByWindowBackground = YES;
        window.minSize = NSMakeSize(700, 500);
        window.delegate = self;
        [self buildContent];
        [self reloadRows];
    }
    return self;
}

- (void)buildContent {
    ReminderBackgroundView *rootView = [[ReminderBackgroundView alloc] init];
    self.window.contentView = rootView;

    NSVisualEffectView *sidebarView = [[NSVisualEffectView alloc] init];
    sidebarView.material = NSVisualEffectMaterialSidebar;
    sidebarView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    sidebarView.state = NSVisualEffectStateFollowsWindowActiveState;
    sidebarView.translatesAutoresizingMaskIntoConstraints = NO;
    [rootView addSubview:sidebarView];

    ReminderSeparatorView *sidebarSeparator = [[ReminderSeparatorView alloc] init];
    sidebarSeparator.translatesAutoresizingMaskIntoConstraints = NO;
    [rootView addSubview:sidebarSeparator];

    self.tabView = [[CategoryTabView alloc] initWithCategories:self.store.categories];
    self.tabView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tabView setSelectedCategoryID:self.store.currentCategoryID];
    __weak typeof(self) weakSelf = self;
    self.tabView.onSelectCategory = ^(NSString *categoryID) {
        [weakSelf selectCategory:categoryID];
    };
    self.tabView.onAddCategory = ^{
        [weakSelf promptToAddCategory];
    };
    self.tabView.onRenameCategory = ^(NSString *categoryID) {
        [weakSelf promptToRenameCategory:categoryID];
    };
    self.tabView.onRemoveCategory = ^(NSString *categoryID) {
        [weakSelf promptToRemoveCategory:categoryID];
    };
    [sidebarView addSubview:self.tabView];

    self.mainView = [[NSView alloc] init];
    self.mainView.translatesAutoresizingMaskIntoConstraints = NO;
    [rootView addSubview:self.mainView];

    self.categoryTitleLabel = [NSTextField labelWithString:@""];
    self.categoryTitleLabel.font = [ReminderTheme semiboldFontOfSize:27];
    self.categoryTitleLabel.textColor = ReminderTheme.primaryTextColor;
    self.categoryTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.mainView addSubview:self.categoryTitleLabel];

    self.itemCountLabel = [NSTextField labelWithString:@""];
    self.itemCountLabel.font = [ReminderTheme regularFontOfSize:12];
    self.itemCountLabel.textColor = ReminderTheme.tertiaryTextColor;
    self.itemCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.mainView addSubview:self.itemCountLabel];

    ReminderSeparatorView *headerSeparator = [[ReminderSeparatorView alloc] init];
    headerSeparator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.mainView addSubview:headerSeparator];

    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.drawsBackground = NO;
    self.scrollView.borderType = NSNoBorder;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.scrollerStyle = NSScrollerStyleOverlay;
    [self.mainView addSubview:self.scrollView];

    self.documentView = [[ReminderFlippedView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    self.documentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.documentView = self.documentView;

    self.stackView = [[NSStackView alloc] init];
    self.stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.stackView.spacing = 8;
    self.stackView.alignment = NSLayoutAttributeWidth;
    self.stackView.distribution = NSStackViewDistributionFill;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.documentView addSubview:self.stackView];

    self.inputBar = [[InputBarView alloc] initWithFrame:NSZeroRect];
    self.inputBar.onSave = ^(NSString *text) {
        [weakSelf saveText:text];
    };
    [self.mainView addSubview:self.inputBar];

    self.emptyStateView = [self makeEmptyStateView];
    [self.mainView addSubview:self.emptyStateView];

    [NSLayoutConstraint activateConstraints:@[
        [sidebarView.leadingAnchor constraintEqualToAnchor:rootView.leadingAnchor],
        [sidebarView.topAnchor constraintEqualToAnchor:rootView.topAnchor],
        [sidebarView.bottomAnchor constraintEqualToAnchor:rootView.bottomAnchor],
        [sidebarView.widthAnchor constraintEqualToConstant:226],

        [self.tabView.leadingAnchor constraintEqualToAnchor:sidebarView.leadingAnchor],
        [self.tabView.trailingAnchor constraintEqualToAnchor:sidebarView.trailingAnchor],
        [self.tabView.topAnchor constraintEqualToAnchor:sidebarView.topAnchor],
        [self.tabView.bottomAnchor constraintEqualToAnchor:sidebarView.bottomAnchor],

        [sidebarSeparator.leadingAnchor constraintEqualToAnchor:sidebarView.trailingAnchor],
        [sidebarSeparator.topAnchor constraintEqualToAnchor:rootView.topAnchor],
        [sidebarSeparator.bottomAnchor constraintEqualToAnchor:rootView.bottomAnchor],
        [sidebarSeparator.widthAnchor constraintEqualToConstant:1],

        [self.mainView.leadingAnchor constraintEqualToAnchor:sidebarSeparator.trailingAnchor],
        [self.mainView.trailingAnchor constraintEqualToAnchor:rootView.trailingAnchor],
        [self.mainView.topAnchor constraintEqualToAnchor:rootView.topAnchor],
        [self.mainView.bottomAnchor constraintEqualToAnchor:rootView.bottomAnchor],

        [self.categoryTitleLabel.topAnchor constraintEqualToAnchor:self.mainView.topAnchor constant:48],
        [self.categoryTitleLabel.leadingAnchor constraintEqualToAnchor:self.mainView.leadingAnchor constant:24],
        [self.categoryTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.itemCountLabel.leadingAnchor constant:-16],

        [self.itemCountLabel.trailingAnchor constraintEqualToAnchor:self.mainView.trailingAnchor constant:-25],
        [self.itemCountLabel.firstBaselineAnchor constraintEqualToAnchor:self.categoryTitleLabel.firstBaselineAnchor],

        [headerSeparator.topAnchor constraintEqualToAnchor:self.categoryTitleLabel.bottomAnchor constant:17],
        [headerSeparator.leadingAnchor constraintEqualToAnchor:self.mainView.leadingAnchor],
        [headerSeparator.trailingAnchor constraintEqualToAnchor:self.mainView.trailingAnchor],
        [headerSeparator.heightAnchor constraintEqualToConstant:1],

        [self.inputBar.leadingAnchor constraintEqualToAnchor:self.mainView.leadingAnchor constant:24],
        [self.inputBar.trailingAnchor constraintEqualToAnchor:self.mainView.trailingAnchor constant:-24],
        [self.inputBar.bottomAnchor constraintEqualToAnchor:self.mainView.bottomAnchor constant:-22],
        [self.inputBar.heightAnchor constraintGreaterThanOrEqualToConstant:50],

        [self.scrollView.topAnchor constraintEqualToAnchor:headerSeparator.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.mainView.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.mainView.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.inputBar.topAnchor constant:-17],

        [self.documentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentView.leadingAnchor],
        [self.documentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentView.trailingAnchor],
        [self.documentView.topAnchor constraintEqualToAnchor:self.scrollView.contentView.topAnchor],
        [self.documentView.widthAnchor constraintEqualToAnchor:self.scrollView.contentView.widthAnchor],
        [self.documentView.heightAnchor constraintGreaterThanOrEqualToAnchor:self.scrollView.contentView.heightAnchor],

        [self.stackView.leadingAnchor constraintEqualToAnchor:self.documentView.leadingAnchor constant:24],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.documentView.trailingAnchor constant:-24],
        [self.stackView.topAnchor constraintEqualToAnchor:self.documentView.topAnchor constant:16],
        [self.stackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.documentView.bottomAnchor constant:-16],

        [self.emptyStateView.centerXAnchor constraintEqualToAnchor:self.scrollView.centerXAnchor],
        [self.emptyStateView.centerYAnchor constraintEqualToAnchor:self.scrollView.centerYAnchor constant:-6],
        [self.emptyStateView.widthAnchor constraintLessThanOrEqualToAnchor:self.scrollView.widthAnchor constant:-48]
    ]];
}

- (NSView *)makeEmptyStateView {
    NSView *emptyView = [[NSView alloc] init];
    emptyView.translatesAutoresizingMaskIntoConstraints = NO;

    NSImageView *imageView = [[NSImageView alloc] init];
    NSImage *image = [NSImage imageWithSystemSymbolName:@"note.text" accessibilityDescription:@"空列表"];
    NSImageSymbolConfiguration *configuration = [NSImageSymbolConfiguration configurationWithPointSize:34
                                                                                                  weight:NSFontWeightRegular
                                                                                                   scale:NSImageSymbolScaleMedium];
    imageView.image = [image imageWithSymbolConfiguration:configuration];
    imageView.contentTintColor = ReminderTheme.tertiaryTextColor;
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    [emptyView addSubview:imageView];

    NSTextField *titleLabel = [NSTextField labelWithString:@"这里还没有内容"];
    titleLabel.font = [ReminderTheme semiboldFontOfSize:16];
    titleLabel.textColor = ReminderTheme.secondaryTextColor;
    titleLabel.alignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [emptyView addSubview:titleLabel];

    self.emptyStateDescriptionLabel = [NSTextField labelWithString:@"在下方输入后按 Return 保存。"];
    self.emptyStateDescriptionLabel.font = [ReminderTheme regularFontOfSize:13];
    self.emptyStateDescriptionLabel.textColor = ReminderTheme.tertiaryTextColor;
    self.emptyStateDescriptionLabel.alignment = NSTextAlignmentCenter;
    self.emptyStateDescriptionLabel.maximumNumberOfLines = 2;
    self.emptyStateDescriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [emptyView addSubview:self.emptyStateDescriptionLabel];

    [NSLayoutConstraint activateConstraints:@[
        [imageView.topAnchor constraintEqualToAnchor:emptyView.topAnchor],
        [imageView.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
        [imageView.widthAnchor constraintEqualToConstant:40],
        [imageView.heightAnchor constraintEqualToConstant:40],
        [titleLabel.topAnchor constraintEqualToAnchor:imageView.bottomAnchor constant:12],
        [titleLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor],
        [self.emptyStateDescriptionLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
        [self.emptyStateDescriptionLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor],
        [self.emptyStateDescriptionLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor],
        [self.emptyStateDescriptionLabel.bottomAnchor constraintEqualToAnchor:emptyView.bottomAnchor]
    ]];
    return emptyView;
}

- (void)promptToAddCategory {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"新建栏目";
    alert.informativeText = @"输入栏目名称（最多 40 个字符）。新栏目中的内容操作方式与“工作”一致。";
    [alert addButtonWithTitle:@"创建"];
    [alert addButtonWithTitle:@"取消"];

    NSTextField *nameField = [self categoryNameFieldWithValue:@"" placeholder:@"栏目名称"];
    alert.accessoryView = nameField;
    alert.window.initialFirstResponder = nameField;

    __weak typeof(self) weakSelf = self;
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode != NSAlertFirstButtonReturn) {
            [weakSelf.inputBar focusInput];
            return;
        }
        NSString *categoryID = [weakSelf.store addCategoryWithDisplayName:nameField.stringValue];
        if (categoryID.length == 0) {
            [weakSelf showToastWithText:@"名称无效或已存在"];
            [weakSelf.inputBar focusInput];
            return;
        }
        [weakSelf.store switchToCategory:categoryID];
        [weakSelf refreshCategoriesAndRows];
        [weakSelf showToastWithText:@"栏目已创建"];
        [weakSelf.inputBar focusInput];
    }];
}

- (void)promptToRenameCategory:(NSString *)categoryID {
    ReminderCategory *category = [self.store categoryForIdentifier:categoryID];
    if (!category) {
        return;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"重命名栏目";
    alert.informativeText = [NSString stringWithFormat:@"为“%@”输入一个新名称（最多 40 个字符）。", category.displayName];
    [alert addButtonWithTitle:@"重命名"];
    [alert addButtonWithTitle:@"取消"];

    NSTextField *nameField = [self categoryNameFieldWithValue:category.displayName placeholder:@"栏目名称"];
    alert.accessoryView = nameField;
    alert.window.initialFirstResponder = nameField;

    __weak typeof(self) weakSelf = self;
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode != NSAlertFirstButtonReturn) {
            [weakSelf.inputBar focusInput];
            return;
        }
        if (![weakSelf.store renameCategoryWithIdentifier:categoryID displayName:nameField.stringValue]) {
            [weakSelf showToastWithText:@"名称无效或已存在"];
            [weakSelf.inputBar focusInput];
            return;
        }
        [weakSelf refreshCategoriesAndRows];
        [weakSelf showToastWithText:@"栏目已重命名"];
        [weakSelf.inputBar focusInput];
    }];
}

- (void)promptToRemoveCategory:(NSString *)categoryID {
    ReminderCategory *category = [self.store categoryForIdentifier:categoryID];
    if (!category || self.store.categories.count <= 1) {
        return;
    }

    NSUInteger itemCount = [self.store itemsForCategory:categoryID].count;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleCritical;
    alert.messageText = [NSString stringWithFormat:@"移除“%@”？", category.displayName];
    alert.informativeText = [NSString stringWithFormat:@"此操作会永久删除该栏目及其中的 %lu 条内容。请输入“%@”确认。",
                             (unsigned long)itemCount,
                             category.displayName];
    [alert addButtonWithTitle:@"移除"];
    [alert addButtonWithTitle:@"取消"];

    NSTextField *confirmationField = [self categoryNameFieldWithValue:@"" placeholder:category.displayName];
    alert.accessoryView = confirmationField;
    alert.window.initialFirstResponder = confirmationField;

    NSString *expectedName = category.displayName;
    __weak typeof(self) weakSelf = self;
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode != NSAlertFirstButtonReturn) {
            [weakSelf.inputBar focusInput];
            return;
        }
        if (![confirmationField.stringValue isEqualToString:expectedName]) {
            [weakSelf showToastWithText:@"栏目名称不匹配，未移除"];
            [weakSelf.inputBar focusInput];
            return;
        }
        if (![weakSelf.store removeCategoryWithIdentifier:categoryID]) {
            [weakSelf showToastWithText:@"至少需要保留一个栏目"];
            [weakSelf.inputBar focusInput];
            return;
        }
        [weakSelf refreshCategoriesAndRows];
        [weakSelf showToastWithText:@"栏目已移除"];
        [weakSelf.inputBar focusInput];
    }];
}

- (NSTextField *)categoryNameFieldWithValue:(NSString *)value placeholder:(NSString *)placeholder {
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 320, 24)];
    field.stringValue = value ?: @"";
    field.placeholderString = placeholder;
    field.font = [ReminderTheme regularFontOfSize:13];
    field.accessibilityLabel = @"栏目名称";
    return field;
}

- (void)refreshCategoriesAndRows {
    [self.tabView setCategories:self.store.categories];
    [self.tabView setSelectedCategoryID:self.store.currentCategoryID];
    [self reloadRows];
    [self.scrollView.contentView scrollToPoint:NSZeroPoint];
    [self.scrollView reflectScrolledClipView:self.scrollView.contentView];
}

- (void)selectCategory:(NSString *)categoryID {
    if (![self.store switchToCategory:categoryID]) {
        return;
    }
    [self.tabView setSelectedCategoryID:self.store.currentCategoryID];
    [self reloadRows];
    [self.scrollView.contentView scrollToPoint:NSZeroPoint];
    [self.scrollView reflectScrolledClipView:self.scrollView.contentView];
    [self.inputBar focusInput];
}

- (void)saveText:(NSString *)text {
    if ([self.store addItemWithContent:text]) {
        [self.inputBar clearInput];
        [self reloadRows];
        [self.scrollView.contentView scrollToPoint:NSZeroPoint];
        [self.scrollView reflectScrolledClipView:self.scrollView.contentView];
        [self showToastWithText:@"已保存"];
    }
    [self.inputBar focusInput];
}

- (void)reloadRows {
    BOOL shouldAnimate = self.window.isVisible;
    if (shouldAnimate) {
        self.stackView.alphaValue = 0.0;
    }

    NSArray *arrangedSubviews = [self.stackView.arrangedSubviews copy];
    for (NSView *view in arrangedSubviews) {
        [self.stackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    ReminderCategory *category = [self.store categoryForIdentifier:self.store.currentCategoryID];
    __weak typeof(self) weakSelf = self;
    for (ReminderItem *item in self.store.currentItems) {
        ReminderRowView *row = [[ReminderRowView alloc] initWithItem:item category:category];
        row.onCopy = ^(ReminderItem *copiedItem) {
            [weakSelf copyItem:copiedItem];
        };
        row.onDelete = ^(ReminderItem *deletedItem) {
            [weakSelf deleteItem:deletedItem];
        };
        [self.stackView addArrangedSubview:row];
        [row.widthAnchor constraintEqualToAnchor:self.stackView.widthAnchor].active = YES;
    }

    [self updateContentSummary];

    if (shouldAnimate) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.16;
            self.stackView.animator.alphaValue = 1.0;
        } completionHandler:nil];
    } else {
        self.stackView.alphaValue = 1.0;
    }
}

- (void)updateContentSummary {
    ReminderCategory *category = [self.store categoryForIdentifier:self.store.currentCategoryID];
    NSUInteger itemCount = self.store.currentItems.count;
    self.categoryTitleLabel.stringValue = category.displayName ?: @"";
    self.itemCountLabel.stringValue = [NSString stringWithFormat:@"%lu 条备忘", (unsigned long)itemCount];
    self.emptyStateView.hidden = itemCount > 0;
    self.emptyStateDescriptionLabel.stringValue = [category.identifier isEqualToString:@"quickCommand"]
        ? @"保存常用命令，之后可以一键复制。"
        : @"在下方输入后按 Return 保存。";
    [self.inputBar setCategoryDisplayName:category.displayName];

    NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    for (ReminderCategory *knownCategory in self.store.categories) {
        counts[knownCategory.identifier] = @([self.store itemsForCategory:knownCategory.identifier].count);
    }
    [self.tabView updateItemCounts:counts];
}

- (void)copyItem:(ReminderItem *)item {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    BOOL copied = [pasteboard setString:item.content forType:NSPasteboardTypeString];
    if (copied) {
        [self showToastWithText:@"已复制"];
    } else {
        [self showToastWithText:@"复制失败"];
    }
    [self.inputBar focusInput];
}

- (void)showCopyToast {
    [self showToastWithText:@"已复制"];
}

- (void)showToastWithText:(NSString *)text {
    NSView *rootView = self.window.contentView;
    if (!rootView) {
        return;
    }

    if (!self.successToastLabel) {
        self.successToastLabel = [self makeToastLabel];
        [rootView addSubview:self.successToastLabel positioned:NSWindowAbove relativeTo:nil];
        [NSLayoutConstraint activateConstraints:@[
            [self.successToastLabel.centerXAnchor constraintEqualToAnchor:self.mainView.centerXAnchor],
            [self.successToastLabel.bottomAnchor constraintEqualToAnchor:self.inputBar.topAnchor constant:-10],
            [self.successToastLabel.widthAnchor constraintGreaterThanOrEqualToConstant:88],
            [self.successToastLabel.heightAnchor constraintEqualToConstant:30]
        ]];
    }

    [self.successToastTimer invalidate];
    self.successToastTimer = nil;
    self.successToastLabel.stringValue = text;
    self.successToastLabel.hidden = NO;
    self.successToastLabel.alphaValue = 0.0;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.14;
        self.successToastLabel.animator.alphaValue = 1.0;
    } completionHandler:nil];
    NSAccessibilityPostNotificationWithUserInfo(self.successToastLabel,
                                                NSAccessibilityAnnouncementRequestedNotification,
                                                @{
        NSAccessibilityAnnouncementKey: text,
        NSAccessibilityPriorityKey: @(NSAccessibilityPriorityMedium)
    });
    self.successToastTimer = [NSTimer scheduledTimerWithTimeInterval:1.35
                                                              target:self
                                                            selector:@selector(hideCopyToast:)
                                                            userInfo:nil
                                                             repeats:NO];
}

- (NSTextField *)makeToastLabel {
    NSTextField *label = [NSTextField labelWithString:@"已复制"];
    label.cell = [[ReminderToastTextFieldCell alloc] initTextCell:@"已复制"];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.alignment = NSTextAlignmentCenter;
    label.font = [ReminderTheme semiboldFontOfSize:12];
    label.textColor = NSColor.whiteColor;
    label.wantsLayer = YES;
    label.layer.backgroundColor = ReminderTheme.toastBackgroundColor.CGColor;
    label.layer.cornerRadius = 15.0;
    label.layer.masksToBounds = YES;
    return label;
}

- (void)hideCopyToast:(NSTimer *)timer {
    (void)timer;
    self.successToastTimer = nil;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.18;
        self.successToastLabel.animator.alphaValue = 0.0;
    } completionHandler:^{
        self.successToastLabel.hidden = YES;
    }];
}

- (void)deleteItem:(ReminderItem *)item {
    [self.store deleteItemWithID:item.itemID categoryID:item.categoryID];
    [self reloadRows];
    [self showToastWithText:@"已删除"];
    [self.inputBar focusInput];
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    [sender orderOut:nil];
    return NO;
}

- (void)showAndFocus {
    [self showWindow:nil];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self.inputBar focusInput];
}

- (void)dealloc {
    [self.successToastTimer invalidate];
}

@end
