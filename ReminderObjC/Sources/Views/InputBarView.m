#import "InputBarView.h"
#import "../Theme/ReminderTheme.h"

static const CGFloat ReminderInputHorizontalInset = 20.0;

@interface ReminderVerticallyCenteredTextFieldCell : NSTextFieldCell
@end

@implementation ReminderVerticallyCenteredTextFieldCell

- (NSRect)centeredTextRectForBounds:(NSRect)rect {
    NSRect drawingRect = [super drawingRectForBounds:rect];
    CGFloat textHeight = ceil(self.font.ascender - self.font.descender) + 2.0;
    if (textHeight <= 0 || textHeight > NSHeight(rect)) {
        return drawingRect;
    }

    drawingRect.origin.y = NSMinY(rect) + floor((NSHeight(rect) - textHeight) / 2.0);
    drawingRect.size.height = textHeight;
    return drawingRect;
}

- (NSRect)drawingRectForBounds:(NSRect)rect {
    return [self centeredTextRectForBounds:rect];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [super drawInteriorWithFrame:[self centeredTextRectForBounds:cellFrame] inView:controlView];
}

- (void)editWithFrame:(NSRect)aRect
                inView:(NSView *)controlView
                editor:(NSText *)textObj
              delegate:(id)anObject
                 event:(NSEvent *)theEvent {
    [super editWithFrame:[self centeredTextRectForBounds:aRect]
                  inView:controlView
                  editor:textObj
                delegate:anObject
                   event:theEvent];
}

- (void)selectWithFrame:(NSRect)aRect
                  inView:(NSView *)controlView
                  editor:(NSText *)textObj
                delegate:(id)anObject
                   start:(NSInteger)selStart
                  length:(NSInteger)selLength {
    [super selectWithFrame:[self centeredTextRectForBounds:aRect]
                    inView:controlView
                    editor:textObj
                  delegate:anObject
                     start:selStart
                    length:selLength];
}

@end

@interface ReminderInputTextField : NSTextField
@end

@implementation ReminderInputTextField

- (NSEdgeInsets)alignmentRectInsets {
    return NSEdgeInsetsMake(0, 0, 0, 0);
}

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    NSString *key = event.charactersIgnoringModifiers.lowercaseString;
    NSEventModifierFlags flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    BOOL isPasteShortcut = event.type == NSEventTypeKeyDown
        && [key isEqualToString:@"v"]
        && (flags & NSEventModifierFlagCommand) != 0
        && (flags & (NSEventModifierFlagOption | NSEventModifierFlagControl)) == 0;

    if (isPasteShortcut && [self pasteFromGeneralPasteboard]) {
        return YES;
    }

    return [super performKeyEquivalent:event];
}

- (BOOL)pasteFromGeneralPasteboard {
    if (!self.enabled || !self.editable) {
        return NO;
    }

    NSString *pasteText = [NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString];
    if (pasteText.length == 0) {
        return NO;
    }

    NSText *editor = self.currentEditor;
    if (editor) {
        [editor replaceCharactersInRange:editor.selectedRange withString:pasteText];
    } else {
        NSString *currentText = self.stringValue ?: @"";
        self.stringValue = [currentText stringByAppendingString:pasteText];
    }

    id<NSTextFieldDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(controlTextDidChange:)]) {
        NSNotification *notification = [NSNotification notificationWithName:NSControlTextDidChangeNotification object:self];
        [delegate controlTextDidChange:notification];
    }

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
@property (nonatomic, strong) NSTextField *textField;
@property (nonatomic, strong) NSButton *saveButton;
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

        _textField = [[ReminderInputTextField alloc] init];
        _textField.cell = [[ReminderVerticallyCenteredTextFieldCell alloc] initTextCell:@""];
        _textField.delegate = self;
        _textField.target = self;
        _textField.action = @selector(savePressed:);
        _textField.enabled = YES;
        _textField.editable = YES;
        _textField.selectable = YES;
        _textField.font = [ReminderTheme regularFontOfSize:15];
        _textField.textColor = ReminderTheme.primaryTextColor;
        _textField.backgroundColor = NSColor.clearColor;
        _textField.drawsBackground = NO;
        _textField.bezeled = NO;
        _textField.focusRingType = NSFocusRingTypeNone;
        _textField.placeholderAttributedString = [[NSAttributedString alloc] initWithString:@"写下新的内容…"
                                                                                 attributes:@{
            NSForegroundColorAttributeName: ReminderTheme.placeholderColor,
            NSFontAttributeName: [ReminderTheme regularFontOfSize:15]
        }];
        _textField.toolTip = @"输入内容，按 Return 保存";
        _textField.accessibilityLabel = @"新建内容";
        _textField.accessibilityHelp = @"输入后按 Return 或保存按钮添加到当前文件夹";
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        [_inputContainer addSubview:_textField];

        _saveButton = [ReminderSaveButton buttonWithTitle:@"保存" target:self action:@selector(savePressed:)];
        _saveButton.toolTip = @"保存（Return）";
        _saveButton.accessibilityLabel = @"保存";
        _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_inputContainer addSubview:_saveButton];

        [NSLayoutConstraint activateConstraints:@[
            [_inputContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_inputContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_inputContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_inputContainer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

            [_textField.leadingAnchor constraintEqualToAnchor:_inputContainer.leadingAnchor constant:ReminderInputHorizontalInset],
            [_textField.trailingAnchor constraintEqualToAnchor:_saveButton.leadingAnchor constant:-14],
            [_textField.centerYAnchor constraintEqualToAnchor:_inputContainer.centerYAnchor],
            [_textField.heightAnchor constraintEqualToConstant:24],

            [_saveButton.trailingAnchor constraintEqualToAnchor:_inputContainer.trailingAnchor constant:-7],
            [_saveButton.centerYAnchor constraintEqualToAnchor:_inputContainer.centerYAnchor],
            [_saveButton.widthAnchor constraintEqualToConstant:66],
            [_saveButton.heightAnchor constraintEqualToConstant:34],
        ]];

        [self updateSaveButton];
    }
    return self;
}

- (void)controlTextDidChange:(NSNotification *)notification {
    (void)notification;
    [self updateSaveButton];
}

- (void)controlTextDidBeginEditing:(NSNotification *)notification {
    (void)notification;
    self.inputFocused = YES;
    [self updateContainerAppearance];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    (void)notification;
    self.inputFocused = NO;
    [self updateContainerAppearance];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    (void)control;
    (void)textView;
    if (commandSelector == @selector(insertNewline:)) {
        [self savePressed:nil];
        return YES;
    }
    return NO;
}

- (void)savePressed:(id)sender {
    (void)sender;
    NSString *text = self.textField.stringValue ?: @"";
    if (self.onSave) {
        self.onSave(text);
    }
    [self updateSaveButton];
}

- (void)focusInput {
    [self.window makeFirstResponder:self.textField];
}

- (void)clearInput {
    self.textField.stringValue = @"";
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

- (void)updateContainerAppearance {
    self.inputContainer.layer.backgroundColor = ReminderTheme.inputBackgroundColor.CGColor;
    self.inputContainer.layer.borderColor = (self.inputFocused ? ReminderTheme.focusRingColor : ReminderTheme.inputBorderColor).CGColor;
    self.inputContainer.layer.borderWidth = self.inputFocused ? 2.0 : 1.0;
    self.inputContainer.layer.shadowOpacity = self.inputFocused ? 0.13 : 0.08;
}

- (void)updateSaveButton {
    NSString *trimmed = [self.textField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    BOOL enabled = trimmed.length > 0;
    self.saveButton.enabled = enabled;
}

@end
