#import <AppKit/AppKit.h>
#import <math.h>
#import "../Sources/Store/ReminderStore.h"
#import "../Sources/Theme/ReminderTheme.h"
#import "../Sources/Views/InputBarView.h"
#import "../Sources/Views/ReminderRowView.h"
#import "../Sources/Views/ReminderWindowController.h"

static NSUInteger gFailures = 0;

#define AssertTrue(condition, message) \
    do { \
        if (!(condition)) { \
            gFailures++; \
            NSLog(@"FAIL: %s", message); \
        } \
    } while (0)

#define AssertEqualObjects(actual, expected, message) \
    do { \
        id actualValue = (actual); \
        id expectedValue = (expected); \
        if (![actualValue isEqual:expectedValue]) { \
            gFailures++; \
            NSLog(@"FAIL: %s (expected %@, got %@)", message, expectedValue, actualValue); \
        } \
    } while (0)

static NSURL *TemporaryStoreURL(void) {
    NSString *name = [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"json"];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

static void TestListDocumentViewUsesTopOrigin(void) {
    [NSApplication sharedApplication];
    ReminderStore *store = [[ReminderStore alloc] initWithStorageURL:TemporaryStoreURL()];
    [store addItemWithContent:@"first"];
    [store addItemWithContent:@"second"];

    ReminderWindowController *controller = [[ReminderWindowController alloc] initWithStore:store];
    NSView *documentView = [controller valueForKey:@"documentView"];

    AssertTrue(documentView.isFlipped, "list document view must use a top-left origin");
}

static void TestInputPlaceholderUsesTwentyPointInsetAndVerticalCenter(void) {
    InputBarView *inputBar = [[InputBarView alloc] initWithFrame:NSMakeRect(0, 0, 320, 44)];
    inputBar.translatesAutoresizingMaskIntoConstraints = YES;
    [inputBar layoutSubtreeIfNeeded];

    NSTextField *textField = [inputBar valueForKey:@"textField"];
    NSView *fieldParent = textField.superview;
    NSRect fieldFrame = textField.frame;
    NSRect drawingRect = [textField.cell drawingRectForBounds:textField.bounds];
    CGFloat textStartX = NSMinX(fieldFrame) + NSMinX(drawingRect);
    CGFloat textMidY = NSMinY(fieldFrame) + NSMidY(drawingRect);

    AssertTrue(textField.isEnabled, "input text field must be enabled");
    AssertTrue(textField.isEditable, "input text field must be editable");
    AssertTrue(textField.isSelectable, "input text field must be selectable");
    AssertTrue(fabs(textStartX - 20.0) <= 0.5, "input text must start 20px from the left edge");
    AssertTrue(fabs(textMidY - NSMidY(fieldParent.bounds)) <= 0.5, "input text must be vertically centered");
}

static void TestInputCommandVPastesClipboardText(void) {
    InputBarView *inputBar = [[InputBarView alloc] initWithFrame:NSMakeRect(0, 0, 320, 44)];
    NSTextField *textField = [inputBar valueForKey:@"textField"];
    NSButton *saveButton = [inputBar valueForKey:@"saveButton"];

    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard declareTypes:@[NSPasteboardTypeString] owner:nil];
    AssertTrue([pasteboard setString:@"pasted command" forType:NSPasteboardTypeString], "test must write text to the pasteboard");

    NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown
                                      location:NSZeroPoint
                                 modifierFlags:NSEventModifierFlagCommand
                                     timestamp:0
                                  windowNumber:0
                                       context:nil
                                    characters:@"v"
                   charactersIgnoringModifiers:@"v"
                                     isARepeat:NO
                                       keyCode:9];

    BOOL handled = [textField performKeyEquivalent:event];

    AssertTrue(handled, "input text field must handle command-v");
    AssertEqualObjects(textField.stringValue, @"pasted command", "command-v must paste clipboard text into the input");
    AssertTrue(saveButton.enabled, "pasted input must enable the save button");
}

static NSEvent *CommandKeyEvent(NSString *characters, unsigned short keyCode) {
    return [NSEvent keyEventWithType:NSEventTypeKeyDown
                            location:NSZeroPoint
                       modifierFlags:NSEventModifierFlagCommand
                           timestamp:0
                        windowNumber:0
                             context:nil
                          characters:characters
         charactersIgnoringModifiers:characters
                           isARepeat:NO
                             keyCode:keyCode];
}

static NSTextField *FindRowTextField(ReminderRowView *row) {
    for (NSView *subview in row.subviews) {
        if ([subview isKindOfClass:NSTextField.class]) {
            return (NSTextField *)subview;
        }
    }
    return nil;
}

static NSButton *FindButtonWithTitle(NSView *view, NSString *title) {
    for (NSView *subview in view.subviews) {
        if ([subview isKindOfClass:NSButton.class]) {
            NSButton *button = (NSButton *)subview;
            if ([button.title isEqualToString:title]) {
                return button;
            }
        }

        NSButton *nestedButton = FindButtonWithTitle(subview, title);
        if (nestedButton) {
            return nestedButton;
        }
    }
    return nil;
}

static NSTextField *FindTextFieldWithString(NSView *view, NSString *string) {
    for (NSView *subview in view.subviews) {
        if ([subview isKindOfClass:NSTextField.class]) {
            NSTextField *textField = (NSTextField *)subview;
            if ([textField.stringValue isEqualToString:string]) {
                return textField;
            }
        }

        NSTextField *nestedTextField = FindTextFieldWithString(subview, string);
        if (nestedTextField) {
            return nestedTextField;
        }
    }
    return nil;
}

static NSColor *TitleColor(NSButton *button) {
    return [button.attributedTitle attribute:NSForegroundColorAttributeName
                                     atIndex:0
                              effectiveRange:nil];
}

static void TestRowTextIsSelectableButNotEditable(void) {
    ReminderItem *item = [[ReminderItem alloc] initWithItemID:@"row-1"
                                                   categoryID:@"work"
                                                      content:@"copy partial text"
                                                    createdAt:[NSDate dateWithTimeIntervalSince1970:0]];
    ReminderCategory *category = [ReminderCategory.defaultCategories firstObject];
    ReminderRowView *row = [[ReminderRowView alloc] initWithItem:item category:category];

    NSTextField *textField = FindRowTextField(row);

    AssertTrue(textField != nil, "row must render item content in a text field");
    AssertEqualObjects(textField.stringValue, @"copy partial text", "row text field must show item content");
    AssertTrue(textField.isEnabled, "row text field must be enabled for selection");
    AssertTrue(textField.isSelectable, "row text field must allow mouse selection for command-c");
    AssertTrue(!textField.isEditable, "row text field must not edit saved item content");
}

static void TestRowTextCommandCCopiesSelectedText(void) {
    [NSApplication sharedApplication];

    ReminderItem *item = [[ReminderItem alloc] initWithItemID:@"row-1"
                                                   categoryID:@"work"
                                                      content:@"copy partial text"
                                                    createdAt:[NSDate dateWithTimeIntervalSince1970:0]];
    ReminderCategory *category = [ReminderCategory.defaultCategories firstObject];
    ReminderRowView *row = [[ReminderRowView alloc] initWithItem:item category:category];
    row.translatesAutoresizingMaskIntoConstraints = YES;
    row.frame = NSMakeRect(0, 0, 360, 44);

    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 360, 80)
                                                   styleMask:NSWindowStyleMaskTitled
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    [window.contentView addSubview:row];

    NSTextField *textField = FindRowTextField(row);
    AssertTrue(textField != nil, "row must render item content in a text field before copy");

    [window makeFirstResponder:textField];
    [textField selectText:nil];
    NSText *editor = textField.currentEditor;
    AssertTrue(editor != nil, "row text field must create a field editor for selected text");
    if (editor) {
        editor.selectedRange = NSMakeRange(5, 7);
    }

    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard declareTypes:@[NSPasteboardTypeString] owner:nil];
    AssertTrue([pasteboard setString:@"unchanged clipboard" forType:NSPasteboardTypeString], "test must seed clipboard before command-c");

    BOOL handled = [textField performKeyEquivalent:CommandKeyEvent(@"c", 8)];

    AssertTrue(handled, "row text field must handle command-c");
    AssertEqualObjects([pasteboard stringForType:NSPasteboardTypeString], @"partial", "command-c must copy selected row text");

    [row removeFromSuperview];
    [window orderOut:nil];
}

static void TestQuickCommandCopyShowsSuccessToast(void) {
    [NSApplication sharedApplication];

    ReminderStore *store = [[ReminderStore alloc] initWithStorageURL:TemporaryStoreURL()];
    [store switchToCategory:@"quickCommand"];
    [store addItemWithContent:@"git status"];

    ReminderWindowController *controller = [[ReminderWindowController alloc] initWithStore:store];
    ReminderItem *item = [store.currentItems firstObject];

    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];

    [controller performSelector:@selector(copyItem:) withObject:item];

    NSTextField *toastLabel = [controller valueForKey:@"successToastLabel"];
    AssertTrue(toastLabel != nil, "copy success must create a toast label");
    AssertEqualObjects(toastLabel.stringValue, @"已复制", "copy success toast must use concise success text");
    AssertTrue(!toastLabel.hidden, "copy success toast must be visible immediately");
    AssertEqualObjects(NSStringFromClass(toastLabel.cell.class), @"ReminderToastTextFieldCell", "copy success toast must use a vertically centered text cell");
    AssertEqualObjects([pasteboard stringForType:NSPasteboardTypeString], @"git status", "copy action must write the command to pasteboard");
}

static void TestQuickCommandCopyButtonHasPressedTextFeedback(void) {
    ReminderItem *item = [[ReminderItem alloc] initWithItemID:@"row-1"
                                                   categoryID:@"quickCommand"
                                                      content:@"git status"
                                                    createdAt:[NSDate dateWithTimeIntervalSince1970:0]];
    ReminderCategory *category = [ReminderCategory.defaultCategories lastObject];
    ReminderRowView *row = [[ReminderRowView alloc] initWithItem:item category:category];
    NSButton *copyButton = FindButtonWithTitle(row, @"复制");

    AssertTrue(copyButton != nil, "quick command row must render a copy button before checking feedback");
    NSColor *normalColor = TitleColor(copyButton);

    [copyButton highlight:YES];
    NSColor *pressedColor = TitleColor(copyButton);
    [copyButton highlight:NO];
    NSColor *restoredColor = TitleColor(copyButton);

    AssertTrue(![pressedColor isEqual:normalColor], "copy button title color must change while pressed");
    AssertEqualObjects(restoredColor, normalColor, "copy button title color must restore after press");
}

static void TestNotesStyleWindowAndEmptyState(void) {
    [NSApplication sharedApplication];
    ReminderStore *store = [[ReminderStore alloc] initWithStorageURL:TemporaryStoreURL()];
    ReminderWindowController *controller = [[ReminderWindowController alloc] initWithStore:store];

    NSTextField *categoryTitle = [controller valueForKey:@"categoryTitleLabel"];
    NSTextField *itemCount = [controller valueForKey:@"itemCountLabel"];
    NSView *emptyState = [controller valueForKey:@"emptyStateView"];
    InputBarView *inputBar = [controller valueForKey:@"inputBar"];
    NSTextField *textField = [inputBar valueForKey:@"textField"];

    AssertTrue((controller.window.styleMask & NSWindowStyleMaskFullSizeContentView) != 0,
               "notes-style window must extend content into the titlebar");
    AssertTrue(controller.window.titleVisibility == NSWindowTitleHidden,
               "notes-style window must use a visually integrated titlebar");
    AssertTrue(controller.window.minSize.width >= 700.0,
               "two-column layout must keep a usable minimum width");
    AssertEqualObjects(categoryTitle.stringValue, @"工作", "main header must show the active folder");
    AssertEqualObjects(itemCount.stringValue, @"0 条备忘", "main header must show the empty item count");
    AssertTrue(!emptyState.hidden, "empty folder must show an empty-state explanation");
    AssertTrue([textField.placeholderAttributedString.string containsString:@"工作"],
               "composer placeholder must identify the active folder");
}

static void TestSaveAndDeleteUpdateSummaryAndFeedback(void) {
    [NSApplication sharedApplication];
    ReminderStore *store = [[ReminderStore alloc] initWithStorageURL:TemporaryStoreURL()];
    ReminderWindowController *controller = [[ReminderWindowController alloc] initWithStore:store];

    [controller performSelector:@selector(saveText:) withObject:@"new note"];

    NSTextField *itemCount = [controller valueForKey:@"itemCountLabel"];
    NSView *emptyState = [controller valueForKey:@"emptyStateView"];
    NSTextField *toastLabel = [controller valueForKey:@"successToastLabel"];
    AssertEqualObjects(itemCount.stringValue, @"1 条备忘", "saving must refresh the visible count");
    AssertTrue(emptyState.hidden, "saving the first item must hide the empty state");
    AssertEqualObjects(toastLabel.stringValue, @"已保存", "saving must provide concise success feedback");

    ReminderItem *item = store.currentItems.firstObject;
    [controller performSelector:@selector(deleteItem:) withObject:item];

    AssertEqualObjects(itemCount.stringValue, @"0 条备忘", "deleting must refresh the visible count");
    AssertTrue(!emptyState.hidden, "deleting the last item must restore the empty state");
    AssertEqualObjects(toastLabel.stringValue, @"已删除", "deleting must provide concise feedback");
}

static void TestRowsUseNotesStyleHeightAndCommandTypography(void) {
    ReminderItem *item = [[ReminderItem alloc] initWithItemID:@"row-1"
                                                   categoryID:@"quickCommand"
                                                      content:@"git status"
                                                    createdAt:[NSDate dateWithTimeIntervalSince1970:0]];
    ReminderCategory *category = [ReminderCategory.defaultCategories lastObject];
    ReminderRowView *row = [[ReminderRowView alloc] initWithItem:item category:category];
    NSTextField *textField = FindRowTextField(row);

    BOOL hasExpectedHeight = NO;
    for (NSLayoutConstraint *constraint in row.constraints) {
        if (constraint.firstItem == row &&
            constraint.firstAttribute == NSLayoutAttributeHeight &&
            fabs(constraint.constant - 66.0) <= 0.5) {
            hasExpectedHeight = YES;
            break;
        }
    }

    AssertTrue(hasExpectedHeight, "notes-style row must use a 66px two-line layout");
    AssertTrue(textField.font.isFixedPitch, "quick command content must use readable monospaced typography");
}

static void TestThemeFollowsLightAndDarkAppearance(void) {
    NSAppearance *lightAppearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    NSAppearance *darkAppearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    __block NSColor *lightBackground = nil;
    __block NSColor *darkBackground = nil;

    [lightAppearance performAsCurrentDrawingAppearance:^{
        lightBackground = [ReminderTheme.backgroundColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    }];
    [darkAppearance performAsCurrentDrawingAppearance:^{
        darkBackground = [ReminderTheme.backgroundColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    }];

    AssertTrue(lightBackground != nil && darkBackground != nil,
               "theme colors must resolve in both system appearances");
    AssertTrue(![lightBackground isEqual:darkBackground],
               "theme background must adapt between light and dark appearance");
}

static void TestSidebarUsesFullWidthAlignment(void) {
    [NSApplication sharedApplication];
    ReminderStore *store = [[ReminderStore alloc] initWithStorageURL:TemporaryStoreURL()];
    ReminderWindowController *controller = [[ReminderWindowController alloc] initWithStore:store];
    [controller.window.contentView layoutSubtreeIfNeeded];

    NSView *tabView = [controller valueForKey:@"tabView"];
    NSDictionary *buttons = [tabView valueForKey:@"buttonsByCategory"];
    NSButton *workButton = buttons[@"work"];
    NSTextField *titleLabel = [workButton valueForKey:@"titleLabel"];
    NSTextField *countLabel = [workButton valueForKey:@"countLabel"];
    NSTextField *appTitle = FindTextFieldWithString(tabView, @"Reminder");

    AssertTrue(appTitle != nil, "sidebar app title must use Reminder");
    AssertTrue(fabs(NSWidth(workButton.frame) - (NSWidth(tabView.bounds) - 20.0)) <= 0.5,
               "sidebar rows must fill the available width");
    AssertTrue(titleLabel.alignment == NSTextAlignmentLeft || titleLabel.alignment == NSTextAlignmentNatural,
               "sidebar icon and title group must align left");
    AssertTrue(countLabel.alignment == NSTextAlignmentRight,
               "sidebar live count must align right");
}

int main(void) {
    @autoreleasepool {
        TestListDocumentViewUsesTopOrigin();
        TestInputPlaceholderUsesTwentyPointInsetAndVerticalCenter();
        TestInputCommandVPastesClipboardText();
        TestRowTextIsSelectableButNotEditable();
        TestRowTextCommandCCopiesSelectedText();
        TestQuickCommandCopyShowsSuccessToast();
        TestQuickCommandCopyButtonHasPressedTextFeedback();
        TestNotesStyleWindowAndEmptyState();
        TestSaveAndDeleteUpdateSummaryAndFeedback();
        TestRowsUseNotesStyleHeightAndCommandTypography();
        TestThemeFollowsLightAndDarkAppearance();
        TestSidebarUsesFullWidthAlignment();

        if (gFailures > 0) {
            NSLog(@"%lu layout test failure(s)", (unsigned long)gFailures);
            return 1;
        }

        NSLog(@"All Objective-C layout tests passed");
        return 0;
    }
}
