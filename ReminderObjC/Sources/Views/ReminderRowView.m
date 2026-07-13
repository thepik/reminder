#import "ReminderRowView.h"
#import "../Theme/ReminderTheme.h"

@interface ReminderRowTextField : NSTextField
@end

@implementation ReminderRowTextField

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

- (void)copy:(id)sender {
    (void)sender;
    [self copySelectionToGeneralPasteboard];
}

- (BOOL)copySelectionToGeneralPasteboard {
    if (!self.enabled || !self.selectable) {
        return NO;
    }

    NSText *editor = self.currentEditor;
    if (!editor || editor.selectedRange.length == 0) {
        return NO;
    }

    NSString *source = editor.string ?: self.stringValue ?: @"";
    NSRange selectedRange = editor.selectedRange;
    if (NSMaxRange(selectedRange) > source.length) {
        return NO;
    }

    NSString *selectedText = [source substringWithRange:selectedRange];
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

        NSTextField *label = [[ReminderRowTextField alloc] init];
        label.stringValue = item.content ?: @"";
        label.editable = NO;
        label.selectable = YES;
        label.enabled = YES;
        label.bordered = NO;
        label.bezeled = NO;
        label.drawsBackground = NO;
        label.focusRingType = NSFocusRingTypeNone;
        label.font = [category.identifier isEqualToString:@"quickCommand"]
            ? [ReminderTheme monospacedFontOfSize:14]
            : [ReminderTheme mediumFontOfSize:15];
        label.textColor = ReminderTheme.primaryTextColor;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        label.maximumNumberOfLines = 1;
        label.toolTip = item.content ?: @"";
        label.accessibilityLabel = item.content ?: @"";
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:label];

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

        NSMutableArray *constraints = [NSMutableArray arrayWithArray:@[
            [self.heightAnchor constraintEqualToConstant:66],
            [label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [label.topAnchor constraintEqualToAnchor:self.topAnchor constant:11],
            [label.heightAnchor constraintEqualToConstant:22],
            [dateLabel.leadingAnchor constraintEqualToAnchor:label.leadingAnchor],
            [dateLabel.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:3],
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
                [label.trailingAnchor constraintLessThanOrEqualToAnchor:copyButton.leadingAnchor constant:-12]
            ]];
        } else {
            [constraints addObject:[label.trailingAnchor constraintLessThanOrEqualToAnchor:deleteButton.leadingAnchor constant:-12]];
        }

        [NSLayoutConstraint activateConstraints:constraints];
    }
    return self;
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
