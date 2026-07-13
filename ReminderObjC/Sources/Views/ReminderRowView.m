#import "ReminderRowView.h"
#import "../Theme/ReminderTheme.h"

static const CGFloat ReminderRowMinimumHeight = 66.0;
static const CGFloat ReminderRowMinimumTextHeight = 22.0;
static const NSUInteger ReminderRowMaximumVisibleLines = 3;

static NSScrollView *ReminderAncestorScrollView(NSView *view) {
    NSView *ancestor = view.superview;
    while (ancestor) {
        if ([ancestor isKindOfClass:NSScrollView.class]) {
            return (NSScrollView *)ancestor;
        }
        ancestor = ancestor.superview;
    }
    return nil;
}

@interface ReminderRowContentScrollView : NSScrollView
@end

@implementation ReminderRowContentScrollView

- (void)scrollWheel:(NSEvent *)event {
    NSScrollView *outerScrollView = ReminderAncestorScrollView(self);
    if (!outerScrollView) {
        [super scrollWheel:event];
        return;
    }

    if (!self.hasVerticalScroller) {
        [outerScrollView scrollWheel:event];
        return;
    }

    NSPoint previousOrigin = self.contentView.bounds.origin;
    [super scrollWheel:event];
    NSPoint currentOrigin = self.contentView.bounds.origin;
    BOOL movedVertically = fabs(currentOrigin.y - previousOrigin.y) > 0.01;
    BOOL hasVerticalDelta = fabs(event.scrollingDeltaY) > 0.01 || fabs(event.deltaY) > 0.01;
    if (hasVerticalDelta && !movedVertically) {
        [outerScrollView scrollWheel:event];
    }
}

@end

@interface ReminderRowTextView : NSTextView
@end

@implementation ReminderRowTextView

- (void)scrollWheel:(NSEvent *)event {
    NSScrollView *scrollView = self.enclosingScrollView;
    if (scrollView) {
        [scrollView scrollWheel:event];
    } else {
        [super scrollWheel:event];
    }
}

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    NSString *key = event.charactersIgnoringModifiers.lowercaseString;
    NSEventModifierFlags flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    BOOL isCopyShortcut = event.type == NSEventTypeKeyDown
        && [key isEqualToString:@"c"]
        && (flags & NSEventModifierFlagCommand) != 0
        && (flags & (NSEventModifierFlagOption | NSEventModifierFlagControl)) == 0;

    if (isCopyShortcut && [self copySelectionToGeneralPasteboard]) {
        return YES;
    }

    return [super performKeyEquivalent:event];
}

- (BOOL)copySelectionToGeneralPasteboard {
    if (!self.selectable) {
        return NO;
    }

    NSRange selectedRange = self.selectedRange;
    if (selectedRange.length == 0 || NSMaxRange(selectedRange) > self.string.length) {
        return NO;
    }

    NSString *selectedText = [self.string substringWithRange:selectedRange];
    if (selectedText.length == 0) {
        return NO;
    }

    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    return [pasteboard setString:selectedText forType:NSPasteboardTypeString];
}

@end

@interface ReminderPressFeedbackButton : NSButton
@property (nonatomic, copy) NSString *feedbackTitle;
@property (nonatomic, strong) NSColor *feedbackNormalColor;
@property (nonatomic, strong) NSColor *feedbackPressedColor;
@property (nonatomic, strong) NSColor *feedbackHoverBackgroundColor;
@property (nonatomic) BOOL pointerInside;
@property (nonatomic, strong) NSTrackingArea *hoverTrackingArea;
@end

@implementation ReminderPressFeedbackButton

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.bordered = NO;
        self.wantsLayer = YES;
        self.layer.cornerRadius = 7.0;
        self.layer.masksToBounds = YES;
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

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self updateVisualState];
}

- (void)updateVisualState {
    NSColor *titleColor = self.isHighlighted
        ? (self.feedbackPressedColor ?: self.feedbackNormalColor)
        : self.feedbackNormalColor;
    NSFont *font = self.isHighlighted
        ? [ReminderTheme semiboldFontOfSize:13]
        : [ReminderTheme mediumFontOfSize:13];
    self.attributedTitle = [ReminderTheme buttonTitle:self.feedbackTitle ?: @""
                                                color:titleColor ?: ReminderTheme.secondaryTextColor
                                                 font:font];
    self.layer.backgroundColor = (self.pointerInside && !self.isHighlighted)
        ? (self.feedbackHoverBackgroundColor ?: NSColor.clearColor).CGColor
        : NSColor.clearColor.CGColor;
    self.alphaValue = self.isHighlighted ? 0.72 : 1.0;
}

@end

@interface ReminderRowView ()
@property (nonatomic, strong) ReminderItem *item;
@property (nonatomic, strong) NSScrollView *contentScrollView;
@property (nonatomic, strong) ReminderRowTextView *contentTextView;
@property (nonatomic, strong) NSLayoutConstraint *contentHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *rowHeightConstraint;
@property (nonatomic) BOOL pointerInside;
@property (nonatomic, strong) NSTrackingArea *hoverTrackingArea;
@end

@implementation ReminderRowView

- (instancetype)initWithItem:(ReminderItem *)item category:(ReminderCategory *)category {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _item = item;

        self.wantsLayer = YES;
        self.layer.backgroundColor = ReminderTheme.cardColor.CGColor;
        self.layer.cornerRadius = 11.0;
        self.layer.borderColor = ReminderTheme.separatorColor.CGColor;
        self.layer.borderWidth = 0.5;
        self.translatesAutoresizingMaskIntoConstraints = NO;

        _contentScrollView = [[ReminderRowContentScrollView alloc] init];
        _contentScrollView.borderType = NSNoBorder;
        _contentScrollView.drawsBackground = NO;
        _contentScrollView.hasHorizontalScroller = NO;
        _contentScrollView.hasVerticalScroller = NO;
        _contentScrollView.autohidesScrollers = YES;
        _contentScrollView.scrollerStyle = NSScrollerStyleOverlay;
        _contentScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
        _contentScrollView.verticalScrollElasticity = NSScrollElasticityNone;
        _contentScrollView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_contentScrollView];

        _contentTextView = [[ReminderRowTextView alloc] initWithFrame:NSZeroRect];
        _contentTextView.string = item.content ?: @"";
        _contentTextView.editable = NO;
        _contentTextView.selectable = YES;
        _contentTextView.richText = NO;
        _contentTextView.importsGraphics = NO;
        _contentTextView.drawsBackground = NO;
        _contentTextView.backgroundColor = NSColor.clearColor;
        _contentTextView.textContainerInset = NSZeroSize;
        _contentTextView.textContainer.lineFragmentPadding = 0;
        _contentTextView.textContainer.widthTracksTextView = YES;
        _contentTextView.horizontallyResizable = NO;
        _contentTextView.verticallyResizable = YES;
        _contentTextView.minSize = NSMakeSize(0, ReminderRowMinimumTextHeight);
        _contentTextView.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
        _contentTextView.autoresizingMask = NSViewWidthSizable;
        _contentTextView.font = [category.identifier isEqualToString:@"quickCommand"]
            ? [ReminderTheme monospacedFontOfSize:14]
            : [ReminderTheme mediumFontOfSize:15];
        _contentTextView.textColor = ReminderTheme.primaryTextColor;
        _contentTextView.toolTip = item.content ?: @"";
        _contentTextView.accessibilityLabel = item.content ?: @"";
        _contentScrollView.documentView = _contentTextView;

        NSTextField *dateLabel = [NSTextField labelWithString:[self displayDateForDate:item.createdAt]];
        dateLabel.font = [ReminderTheme regularFontOfSize:11];
        dateLabel.textColor = ReminderTheme.tertiaryTextColor;
        dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:dateLabel];

        NSButton *deleteButton = [self makeTextButton:@"删除"
                                                color:ReminderTheme.dangerColor
                                         pressedColor:ReminderTheme.dangerColor
                                        hoverColor:ReminderTheme.dangerHoverColor
                                               action:@selector(deletePressed:)];
        deleteButton.toolTip = @"删除此条内容";
        deleteButton.accessibilityLabel = @"删除";
        [self addSubview:deleteButton];

        NSButton *copyButton = nil;
        if ((category.rowActions & ReminderRowActionCopy) != 0) {
            copyButton = [self makeTextButton:@"复制"
                                        color:ReminderTheme.secondaryTextColor
                                 pressedColor:ReminderTheme.accentColor
                                   hoverColor:[ReminderTheme.selectedSidebarItemColor colorWithAlphaComponent:0.55]
                                       action:@selector(copyPressed:)];
            copyButton.toolTip = @"复制完整内容";
            copyButton.accessibilityLabel = @"复制";
            [self addSubview:copyButton];
        }

        _rowHeightConstraint = [self.heightAnchor constraintEqualToConstant:ReminderRowMinimumHeight];
        _contentHeightConstraint = [_contentScrollView.heightAnchor constraintEqualToConstant:ReminderRowMinimumTextHeight];
        NSMutableArray *constraints = [NSMutableArray arrayWithArray:@[
            _rowHeightConstraint,
            [_contentScrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [_contentScrollView.topAnchor constraintEqualToAnchor:self.topAnchor constant:11],
            _contentHeightConstraint,
            [dateLabel.leadingAnchor constraintEqualToAnchor:_contentScrollView.leadingAnchor],
            [dateLabel.topAnchor constraintEqualToAnchor:_contentScrollView.bottomAnchor constant:3],
            [deleteButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
            [deleteButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [deleteButton.widthAnchor constraintEqualToConstant:46],
            [deleteButton.heightAnchor constraintEqualToConstant:30]
        ]];

        if (copyButton) {
            [constraints addObjectsFromArray:@[
                [copyButton.trailingAnchor constraintEqualToAnchor:deleteButton.leadingAnchor constant:-4],
                [copyButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
                [copyButton.widthAnchor constraintEqualToConstant:46],
                [copyButton.heightAnchor constraintEqualToConstant:30],
                [_contentScrollView.trailingAnchor constraintEqualToAnchor:copyButton.leadingAnchor constant:-12]
            ]];
        } else {
            [constraints addObject:[_contentScrollView.trailingAnchor constraintEqualToAnchor:deleteButton.leadingAnchor constant:-12]];
        }

        [NSLayoutConstraint activateConstraints:constraints];
    }
    return self;
}

- (void)layout {
    [super layout];
    [self updateContentHeight];
}

- (void)scrollWheel:(NSEvent *)event {
    NSScrollView *outerScrollView = ReminderAncestorScrollView(self);
    if (outerScrollView) {
        [outerScrollView scrollWheel:event];
    } else {
        [super scrollWheel:event];
    }
}

- (void)updateContentHeight {
    CGFloat availableWidth = NSWidth(self.contentScrollView.contentView.bounds);
    if (availableWidth <= 0) {
        return;
    }

    NSRect textFrame = self.contentTextView.frame;
    textFrame.size.width = availableWidth;
    self.contentTextView.frame = textFrame;
    self.contentTextView.textContainer.containerSize = NSMakeSize(availableWidth, CGFLOAT_MAX);
    [self.contentTextView.layoutManager ensureLayoutForTextContainer:self.contentTextView.textContainer];

    CGFloat lineHeight = ceil([self.contentTextView.layoutManager defaultLineHeightForFont:self.contentTextView.font]);
    CGFloat maximumTextHeight = (lineHeight * ReminderRowMaximumVisibleLines) + 4.0;
    CGFloat requiredTextHeight = MAX(ReminderRowMinimumTextHeight,
                                     ceil([self.contentTextView.layoutManager usedRectForTextContainer:self.contentTextView.textContainer].size.height) + 4.0);
    CGFloat visibleTextHeight = MIN(requiredTextHeight, maximumTextHeight);
    BOOL overflows = requiredTextHeight > maximumTextHeight + 0.5;

    NSRect documentFrame = self.contentTextView.frame;
    documentFrame.size.width = availableWidth;
    documentFrame.size.height = MAX(visibleTextHeight, requiredTextHeight);
    self.contentTextView.frame = documentFrame;
    self.contentScrollView.hasVerticalScroller = overflows;

    CGFloat rowHeight = ReminderRowMinimumHeight + (visibleTextHeight - ReminderRowMinimumTextHeight);
    if (fabs(self.contentHeightConstraint.constant - visibleTextHeight) > 0.5 ||
        fabs(self.rowHeightConstraint.constant - rowHeight) > 0.5) {
        self.contentHeightConstraint.constant = visibleTextHeight;
        self.rowHeightConstraint.constant = rowHeight;
        [self.superview setNeedsLayout:YES];
    }
}

- (NSButton *)makeTextButton:(NSString *)title color:(NSColor *)color action:(SEL)action {
    return [self makeTextButton:title color:color pressedColor:nil hoverColor:NSColor.clearColor action:action];
}

- (NSButton *)makeTextButton:(NSString *)title
                       color:(NSColor *)color
                pressedColor:(NSColor *)pressedColor
                  hoverColor:(NSColor *)hoverColor
                      action:(SEL)action {
    ReminderPressFeedbackButton *button = [ReminderPressFeedbackButton buttonWithTitle:title target:self action:action];
    button.feedbackTitle = title;
    button.feedbackNormalColor = color;
    button.feedbackPressedColor = pressedColor ?: color;
    button.feedbackHoverBackgroundColor = hoverColor;
    [button updateVisualState];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

- (NSString *)displayDateForDate:(NSDate *)date {
    NSDate *safeDate = date ?: [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    if ([NSCalendar.currentCalendar isDateInToday:safeDate]) {
        formatter.dateFormat = @"今天 HH:mm";
    } else if ([NSCalendar.currentCalendar isDateInYesterday:safeDate]) {
        formatter.dateFormat = @"昨天 HH:mm";
    } else {
        formatter.dateFormat = @"M月d日 HH:mm";
    }
    return [formatter stringFromDate:safeDate];
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
    [self updateCardAppearance];
}

- (void)mouseExited:(NSEvent *)event {
    (void)event;
    self.pointerInside = NO;
    [self updateCardAppearance];
}

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self updateCardAppearance];
}

- (void)updateCardAppearance {
    self.layer.backgroundColor = (self.pointerInside ? ReminderTheme.cardHoverColor : ReminderTheme.cardColor).CGColor;
    self.layer.borderColor = ReminderTheme.separatorColor.CGColor;
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
