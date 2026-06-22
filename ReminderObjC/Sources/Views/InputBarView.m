#import "InputBarView.h"
#import "../Theme/ReminderTheme.h"

static const CGFloat ReminderInputHorizontalInset = 20.0;

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

@interface InputBarView ()
@property (nonatomic, strong) NSView *inputContainer;
@property (nonatomic, strong) NSTextField *textField;
@property (nonatomic, strong) NSButton *saveButton;
@end

@implementation InputBarView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        _inputContainer = [[NSView alloc] init];
        _inputContainer.wantsLayer = YES;
        _inputContainer.layer.backgroundColor = ReminderTheme.backgroundColor.CGColor;
        _inputContainer.layer.borderColor = ReminderTheme.accentColor.CGColor;
        _inputContainer.layer.borderWidth = 1;
        _inputContainer.layer.cornerRadius = 8;
        _inputContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_inputContainer];

        _textField = [[ReminderInputTextField alloc] init];
        _textField.delegate = self;
        _textField.target = self;
        _textField.action = @selector(savePressed:);
        _textField.enabled = YES;
        _textField.editable = YES;
        _textField.selectable = YES;
        _textField.font = [ReminderTheme mediumFontOfSize:16];
        _textField.textColor = NSColor.whiteColor;
        _textField.backgroundColor = NSColor.clearColor;
        _textField.drawsBackground = NO;
        _textField.bezeled = NO;
        _textField.focusRingType = NSFocusRingTypeNone;
        _textField.placeholderAttributedString = [[NSAttributedString alloc] initWithString:@"请输入..."
                                                                                attributes:@{
            NSForegroundColorAttributeName: ReminderTheme.placeholderColor,
            NSFontAttributeName: [ReminderTheme mediumFontOfSize:16]
        }];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        [_inputContainer addSubview:_textField];

        _saveButton = [NSButton buttonWithTitle:@"保存" target:self action:@selector(savePressed:)];
        _saveButton.bordered = NO;
        _saveButton.wantsLayer = YES;
        _saveButton.layer.cornerRadius = 22;
        _saveButton.layer.backgroundColor = ReminderTheme.accentColor.CGColor;
        _saveButton.attributedTitle = [ReminderTheme buttonTitle:@"保存"
                                                           color:NSColor.whiteColor
                                                            font:[ReminderTheme mediumFontOfSize:16]];
        _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_saveButton];

        [NSLayoutConstraint activateConstraints:@[
            [_inputContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_inputContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_inputContainer.trailingAnchor constraintEqualToAnchor:_saveButton.leadingAnchor constant:-8],
            [_inputContainer.heightAnchor constraintEqualToConstant:44],
            [_inputContainer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

            [_textField.leadingAnchor constraintEqualToAnchor:_inputContainer.leadingAnchor constant:ReminderInputHorizontalInset],
            [_textField.trailingAnchor constraintEqualToAnchor:_inputContainer.trailingAnchor constant:-ReminderInputHorizontalInset],
            [_textField.centerYAnchor constraintEqualToAnchor:_inputContainer.centerYAnchor],
            [_textField.heightAnchor constraintEqualToConstant:24],

            [_saveButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_saveButton.centerYAnchor constraintEqualToAnchor:_inputContainer.centerYAnchor],
            [_saveButton.widthAnchor constraintEqualToConstant:105],
            [_saveButton.heightAnchor constraintEqualToAnchor:_inputContainer.heightAnchor],
        ]];

        [self updateSaveButton];
    }
    return self;
}

- (void)controlTextDidChange:(NSNotification *)notification {
    (void)notification;
    [self updateSaveButton];
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

- (void)updateSaveButton {
    NSString *trimmed = [self.textField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    BOOL enabled = trimmed.length > 0;
    self.saveButton.enabled = enabled;
    self.saveButton.alphaValue = enabled ? 1.0 : 0.45;
}

@end
