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

@interface ReminderWindowController ()
@property (nonatomic, strong) ReminderStore *store;
@property (nonatomic, strong) CategoryTabView *tabView;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSView *documentView;
@property (nonatomic, strong) NSStackView *stackView;
@property (nonatomic, strong) InputBarView *inputBar;
@end

@implementation ReminderWindowController

- (instancetype)initWithStore:(ReminderStore *)store {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 813, 686)
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self = [super initWithWindow:window];
    if (self) {
        _store = store;
        window.title = @"Reminder";
        window.minSize = NSMakeSize(480, 480);
        window.delegate = self;
        [self buildContent];
        [self reloadRows];
    }
    return self;
}

- (void)buildContent {
    NSView *rootView = [[NSView alloc] init];
    rootView.wantsLayer = YES;
    rootView.layer.backgroundColor = ReminderTheme.backgroundColor.CGColor;
    self.window.contentView = rootView;

    self.tabView = [[CategoryTabView alloc] initWithCategories:self.store.categories];
    self.tabView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tabView setSelectedCategoryID:self.store.currentCategoryID];
    __weak typeof(self) weakSelf = self;
    self.tabView.onSelectCategory = ^(NSString *categoryID) {
        [weakSelf selectCategory:categoryID];
    };
    [rootView addSubview:self.tabView];

    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.drawsBackground = NO;
    self.scrollView.borderType = NSNoBorder;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    [rootView addSubview:self.scrollView];

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
    [rootView addSubview:self.inputBar];

    CGFloat tabWidth = self.store.categories.count * 76.0;
    [NSLayoutConstraint activateConstraints:@[
        [self.tabView.topAnchor constraintEqualToAnchor:rootView.topAnchor constant:28],
        [self.tabView.centerXAnchor constraintEqualToAnchor:rootView.centerXAnchor],
        [self.tabView.widthAnchor constraintEqualToConstant:tabWidth],
        [self.tabView.heightAnchor constraintEqualToConstant:26],

        [self.inputBar.leadingAnchor constraintEqualToAnchor:rootView.leadingAnchor constant:40],
        [self.inputBar.trailingAnchor constraintEqualToAnchor:rootView.trailingAnchor constant:-40],
        [self.inputBar.bottomAnchor constraintEqualToAnchor:rootView.bottomAnchor constant:-32],
        [self.inputBar.heightAnchor constraintEqualToConstant:44],

        [self.scrollView.topAnchor constraintEqualToAnchor:self.tabView.bottomAnchor constant:24],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:rootView.leadingAnchor constant:40],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:rootView.trailingAnchor constant:-40],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.inputBar.topAnchor constant:-24],

        [self.documentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentView.leadingAnchor],
        [self.documentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentView.trailingAnchor],
        [self.documentView.topAnchor constraintEqualToAnchor:self.scrollView.contentView.topAnchor],
        [self.documentView.widthAnchor constraintEqualToAnchor:self.scrollView.contentView.widthAnchor],

        [self.stackView.leadingAnchor constraintEqualToAnchor:self.documentView.leadingAnchor],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.documentView.trailingAnchor],
        [self.stackView.topAnchor constraintEqualToAnchor:self.documentView.topAnchor constant:2],
        [self.stackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.documentView.bottomAnchor]
    ]];
}

- (void)selectCategory:(NSString *)categoryID {
    if (![self.store switchToCategory:categoryID]) {
        return;
    }
    [self.tabView setSelectedCategoryID:self.store.currentCategoryID];
    [self reloadRows];
    [self.inputBar focusInput];
}

- (void)saveText:(NSString *)text {
    if ([self.store addItemWithContent:text]) {
        [self.inputBar clearInput];
        [self reloadRows];
        [self.scrollView.contentView scrollToPoint:NSZeroPoint];
        [self.scrollView reflectScrolledClipView:self.scrollView.contentView];
    }
    [self.inputBar focusInput];
}

- (void)reloadRows {
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
}

- (void)copyItem:(ReminderItem *)item {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:item.content forType:NSPasteboardTypeString];
    [self.inputBar focusInput];
}

- (void)deleteItem:(ReminderItem *)item {
    [self.store deleteItemWithID:item.itemID categoryID:item.categoryID];
    [self reloadRows];
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

@end
