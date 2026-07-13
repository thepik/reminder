#import "InputBarView.h"
#import "../Theme/ReminderTheme.h"

static const CGFloat ReminderInputHorizontalInset = 20.0;
static const CGFloat ReminderInputMinimumHeight = 50.0;
static const CGFloat ReminderInputVerticalPadding = 26.0;
static const NSUInteger ReminderInputMaximumVisibleLines = 3;

@interface ReminderInputTextView : NSTextView
@property (nonatomic, copy) NSAttributedString *placeholderAttributedString;
@end

@implementation ReminderInputTextView

- (NSEdgeInsets)alignmentRectInsets {
    return NSEdgeInsetsMake(0, 0, 0, 0);
}

- (void)setPlaceholderAttributedString:(NSAttributedString *)placeholderAttributedString {
    _placeholderAttributedString = [placeholderAttributedString copy];
    [self setNeedsDisplay:YES];
}

- (void)setString:(NSString *)string {
    [super setString:string];
    [self setNeedsDisplay:YES];
}

- (void)didChangeText {
    [super didChangeText];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    if (self.string.length == 0 && self.placeholderAttributedString.length > 0) {
        [self.placeholderAttributedString drawAtPoint:NSMakePoint(self.textContainerInset.width,
                                                                  self.textContainerInset.height)];
    }
}

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    NSString *key = event.charactersIgnoringModifiers.lowercaseString;
    NSEventModifierFlags flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    BOOL isPasteShortcut = event.type == NSEventTypeKeyDown
        && [key isEqualToString:@"v"]
        && (flags & NSEventModifierFlagCommand) != 0
        && (flags & (NSEventModifierFlagOption | NSEventModifierFlagControl)) == 0;

    if (isPasteShortcut && [self pastePlainTextFromGeneralPasteboard]) {
        return YES;
    }

    return [super performKeyEquivalent:event];
}

- (void)paste:(id)sender {
    if (![self pastePlainTextFromGeneralPasteboard]) {
        [super paste:sender];
    }
}

- (BOOL)pastePlainTextFromGeneralPasteboard {
    NSString *pasteText = [NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString];
    NSRange selectedRange = self.selectedRange;
    if (pasteText.length == 0 || NSMaxRange(selectedRange) > self.string.length ||
        ![self shouldChangeTextInRange:selectedRange replacementString:pasteText]) {
        return NO;
    }

    NSMutableDictionary<NSAttributedStringKey, id> *attributes = [self.typingAttributes mutableCopy]
        ?: [NSMutableDictionary dictionary];
    if (self.font) {
        attributes[NSFontAttributeName] = self.font;
    }
    if (self.textColor) {
        attributes[NSForegroundColorAttributeName] = self.textColor;
    }
    NSAttributedString *attributedPaste = [[NSAttributedString alloc] initWithString:pasteText
                                                                          attributes:attributes];
    [self.textStorage replaceCharactersInRange:selectedRange withAttributedString:attributedPaste];
    self.selectedRange = NSMakeRange(selectedRange.location + pasteText.length, 0);
    [self didChangeText];
    return YES;
}

@end

@interface ReminderSaveButton : NSButton
@property (nonatomic) BOOL pointerInside;
@property (nonatomic, strong) NSTrackingArea *hoverTrackingArea;
@end

@implementation ReminderSaveButton

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.bordered = NO;
        self.wantsLayer = YES;
        self.layer.cornerRadius = 9.0;
        self.layer.masksToBounds = YES;
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

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
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
    NSColor *backgroundColor = self.isHighlighted ? ReminderTheme.accentPressedColor : ReminderTheme.accentColor;
    self.layer.backgroundColor = backgroundColor.CGColor;
    self.alphaValue = self.enabled ? (self.pointerInside ? 0.88 : 1.0) : 0.45;
    self.attributedTitle = [ReminderTheme buttonTitle:@"保存"
                                                color:ReminderTheme.accentTextColor
                                                 font:[ReminderTheme semiboldFontOfSize:13]];
}

@end

@interface InputBarView ()
@property (nonatomic, strong) NSView *inputContainer;
@property (nonatomic, strong) NSScrollView *textScrollView;
@property (nonatomic, strong) ReminderInputTextView *textField;
@property (nonatomic, strong) NSButton *saveButton;
@property (nonatomic, strong) NSLayoutConstraint *textAreaHeightConstraint;
@property (nonatomic) CGFloat preferredHeight;
@property (nonatomic) BOOL inputFocused;
@end

@implementation InputBarView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        _inputContainer = [[NSView alloc] init];
        _inputContainer.wantsLayer = YES;
        _inputContainer.layer.backgroundColor = ReminderTheme.inputBackgroundColor.CGColor;
        _inputContainer.layer.borderColor = ReminderTheme.inputBorderColor.CGColor;
        _inputContainer.layer.borderWidth = 1;
        _inputContainer.layer.cornerRadius = 12;
        _inputContainer.layer.shadowColor = NSColor.blackColor.CGColor;
        _inputContainer.layer.shadowOpacity = 0.08;
        _inputContainer.layer.shadowOffset = NSMakeSize(0, -1);
        _inputContainer.layer.shadowRadius = 6;
        _inputContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_inputContainer];

        _textScrollView = [[NSScrollView alloc] init];
        _textScrollView.borderType = NSNoBorder;
        _textScrollView.drawsBackground = NO;
        _textScrollView.hasHorizontalScroller = NO;
        _textScrollView.hasVerticalScroller = NO;
        _textScrollView.autohidesScrollers = YES;
        _textScrollView.scrollerStyle = NSScrollerStyleOverlay;
        _textScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
        _textScrollView.translatesAutoresizingMaskIntoConstraints = NO;
        [_inputContainer addSubview:_textScrollView];

        _textField = [[ReminderInputTextView alloc] initWithFrame:NSZeroRect];
        _textField.delegate = self;
        _textField.editable = YES;
        _textField.selectable = YES;
        _textField.richText = NO;
        _textField.importsGraphics = NO;
        _textField.usesFindPanel = NO;
        _textField.allowsUndo = YES;
        _textField.font = [ReminderTheme regularFontOfSize:15];
        _textField.textColor = ReminderTheme.primaryTextColor;
        NSMutableDictionary<NSAttributedStringKey, id> *typingAttributes = [_textField.typingAttributes mutableCopy]
            ?: [NSMutableDictionary dictionary];
        typingAttributes[NSFontAttributeName] = _textField.font;
        typingAttributes[NSForegroundColorAttributeName] = _textField.textColor;
        _textField.typingAttributes = typingAttributes;
        _textField.backgroundColor = NSColor.clearColor;
        _textField.drawsBackground = NO;
        _textField.textContainerInset = NSMakeSize(0, 2);
        _textField.textContainer.lineFragmentPadding = 0;
        _textField.textContainer.widthTracksTextView = YES;
        _textField.horizontallyResizable = NO;
        _textField.verticallyResizable = YES;
        _textField.minSize = NSMakeSize(0, 22);
        _textField.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
        _textField.autoresizingMask = NSViewWidthSizable;
        _textField.placeholderAttributedString = [[NSAttributedString alloc] initWithString:@"写下新的内容…"
                                                                                 attributes:@{
            NSForegroundColorAttributeName: ReminderTheme.placeholderColor,
            NSFontAttributeName: [ReminderTheme regularFontOfSize:15]
        }];
        _textField.toolTip = @"输入内容，按 Return 保存";
        _textField.accessibilityLabel = @"新建内容";
        _textField.accessibilityHelp = @"输入后按 Return 或保存按钮添加到当前文件夹";
        _textScrollView.documentView = _textField;

        _saveButton = [ReminderSaveButton buttonWithTitle:@"保存" target:self action:@selector(savePressed:)];
        _saveButton.toolTip = @"保存（Return）";
        _saveButton.accessibilityLabel = @"保存";
        _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_inputContainer addSubview:_saveButton];

        CGFloat lineHeight = ceil([_textField.layoutManager defaultLineHeightForFont:_textField.font]);
        _textAreaHeightConstraint = [_textScrollView.heightAnchor constraintEqualToConstant:MAX(24.0, lineHeight + 4.0)];
        _preferredHeight = ReminderInputMinimumHeight;

        [NSLayoutConstraint activateConstraints:@[
            [_inputContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_inputContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_inputContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_inputContainer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

            [_textScrollView.leadingAnchor constraintEqualToAnchor:_inputContainer.leadingAnchor constant:ReminderInputHorizontalInset],
            [_textScrollView.trailingAnchor constraintEqualToAnchor:_saveButton.leadingAnchor constant:-14],
            [_textScrollView.centerYAnchor constraintEqualToAnchor:_inputContainer.centerYAnchor],
            _textAreaHeightConstraint,

            [_saveButton.trailingAnchor constraintEqualToAnchor:_inputContainer.trailingAnchor constant:-7],
            [_saveButton.centerYAnchor constraintEqualToAnchor:_inputContainer.centerYAnchor],
            [_saveButton.widthAnchor constraintEqualToConstant:66],
            [_saveButton.heightAnchor constraintEqualToConstant:34],
        ]];

        [self updateSaveButton];
    }
    return self;
}

- (void)handleTextChangeNotification:(NSNotification *)notification {
    (void)notification;
    [self updateInputHeight];
    [self updateSaveButton];
}

- (void)textDidChange:(NSNotification *)notification {
    [self handleTextChangeNotification:notification];
}

- (void)textDidBeginEditing:(NSNotification *)notification {
    (void)notification;
    self.inputFocused = YES;
    [self updateContainerAppearance];
}

- (void)textDidEndEditing:(NSNotification *)notification {
    (void)notification;
    self.inputFocused = NO;
    [self updateContainerAppearance];
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    (void)textView;
    if (commandSelector == @selector(insertNewline:)) {
        [self savePressed:nil];
        return YES;
    }
    return NO;
}

- (void)savePressed:(id)sender {
    (void)sender;
    NSString *text = self.textField.string ?: @"";
    if (self.onSave) {
        self.onSave(text);
    }
    [self updateSaveButton];
}

- (void)focusInput {
    [self.window makeFirstResponder:self.textField];
}

- (void)clearInput {
    self.textField.string = @"";
    [self updateInputHeight];
    [self updateSaveButton];
}

- (void)setCategoryDisplayName:(NSString *)displayName {
    NSString *placeholder = displayName.length > 0
        ? [NSString stringWithFormat:@"添加到“%@”…", displayName]
        : @"写下新的内容…";
    self.textField.placeholderAttributedString = [[NSAttributedString alloc] initWithString:placeholder attributes:@{
        NSForegroundColorAttributeName: ReminderTheme.placeholderColor,
        NSFontAttributeName: [ReminderTheme regularFontOfSize:15]
    }];
}

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self updateContainerAppearance];
}

- (NSSize)intrinsicContentSize {
    return NSMakeSize(NSViewNoIntrinsicMetric, self.preferredHeight);
}

- (void)layout {
    [super layout];
    [self updateInputHeight];
}

- (void)updateInputHeight {
    CGFloat availableWidth = NSWidth(self.textScrollView.contentView.bounds);
    if (availableWidth <= 0) {
        return;
    }

    NSRect textFrame = self.textField.frame;
    textFrame.size.width = availableWidth;
    self.textField.frame = textFrame;
    self.textField.textContainer.containerSize = NSMakeSize(availableWidth, CGFLOAT_MAX);
    [self.textField.layoutManager ensureLayoutForTextContainer:self.textField.textContainer];

    CGFloat lineHeight = ceil([self.textField.layoutManager defaultLineHeightForFont:self.textField.font]);
    CGFloat minimumTextHeight = MAX(24.0, lineHeight + 4.0);
    CGFloat maximumTextHeight = (lineHeight * ReminderInputMaximumVisibleLines) + 4.0;
    CGFloat laidOutTextHeight = ceil([self.textField.layoutManager usedRectForTextContainer:self.textField.textContainer].size.height)
        + (self.textField.textContainerInset.height * 2.0);
    CGFloat requiredTextHeight = MAX(minimumTextHeight, laidOutTextHeight);
    CGFloat visibleTextHeight = MIN(requiredTextHeight, maximumTextHeight);
    BOOL overflows = requiredTextHeight > maximumTextHeight + 0.5;

    NSRect documentFrame = self.textField.frame;
    documentFrame.size.width = availableWidth;
    documentFrame.size.height = MAX(visibleTextHeight, requiredTextHeight);
    self.textField.frame = documentFrame;
    self.textScrollView.hasVerticalScroller = overflows;

    CGFloat height = MAX(ReminderInputMinimumHeight, visibleTextHeight + ReminderInputVerticalPadding);
    BOOL heightChanged = fabs(self.textAreaHeightConstraint.constant - visibleTextHeight) > 0.5 ||
        fabs(self.preferredHeight - height) > 0.5;
    if (heightChanged) {
        self.textAreaHeightConstraint.constant = visibleTextHeight;
        self.preferredHeight = height;
        [self invalidateIntrinsicContentSize];
        [self.superview setNeedsLayout:YES];
    }

    if (self.window.firstResponder == self.textField) {
        [self.textField scrollRangeToVisible:self.textField.selectedRange];
    }
}

- (void)updateContainerAppearance {
    self.inputContainer.layer.backgroundColor = ReminderTheme.inputBackgroundColor.CGColor;
    self.inputContainer.layer.borderColor = (self.inputFocused ? ReminderTheme.focusRingColor : ReminderTheme.inputBorderColor).CGColor;
    self.inputContainer.layer.borderWidth = self.inputFocused ? 2.0 : 1.0;
    self.inputContainer.layer.shadowOpacity = self.inputFocused ? 0.13 : 0.08;
}

- (void)updateSaveButton {
    NSString *trimmed = [self.textField.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    BOOL enabled = trimmed.length > 0;
    self.saveButton.enabled = enabled;
}

@end
