#import <AppKit/AppKit.h>
#import <math.h>
#import "../Sources/Store/ReminderStore.h"
#import "../Sources/Theme/ReminderTheme.h"
#import "../Sources/Views/CategoryTabView.h"
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

@interface ReminderRecordingScrollView : NSScrollView
@property (nonatomic) NSUInteger receivedScrollWheelEvents;
@end

@implementation ReminderRecordingScrollView

- (void)scrollWheel:(NSEvent *)event {
    (void)event;
    self.receivedScrollWheelEvents += 1;
}

@end

static NSURL *TemporaryStoreURL(void) {
    NSString *name = [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"json"];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

static ReminderCategory *CategoryWithIdentifier(NSString *identifier) {
    for (ReminderCategory *category in ReminderCategory.defaultCategories) {
        if ([category.identifier isEqualToString:identifier]) {
            return category;
        }
    }
    return nil;
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

    NSTextView *textField = [inputBar valueForKey:@"textField"];
    NSScrollView *textScrollView = [inputBar valueForKey:@"textScrollView"];
    NSView *fieldParent = textScrollView.superview;
    CGFloat textStartX = NSMinX(textScrollView.frame) + textField.textContainerInset.width + textField.textContainer.lineFragmentPadding;
    CGFloat textMidY = NSMidY(textScrollView.frame);

    AssertTrue(textField.isEditable, "input text field must be editable");
    AssertTrue(textField.isSelectable, "input text field must be selectable");
    AssertTrue(fabs(textStartX - 20.0) <= 0.5, "input text must start 20px from the left edge");
    AssertTrue(fabs(textMidY - NSMidY(fieldParent.bounds)) <= 0.5, "input text must be vertically centered");
}

static void TestInputCommandVPastesClipboardText(void) {
    InputBarView *inputBar = [[InputBarView alloc] initWithFrame:NSMakeRect(0, 0, 320, 44)];
    NSTextView *textField = [inputBar valueForKey:@"textField"];
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
    AssertEqualObjects(textField.string, @"pasted command", "command-v must paste clipboard text into the input");
    NSColor *pastedTextColor = [textField.textStorage attribute:NSForegroundColorAttributeName
                                                        atIndex:0
                                                 effectiveRange:nil];
    AssertEqualObjects(pastedTextColor, textField.textColor,
                       "pasted input must use the same text color as keyboard input");
    AssertTrue(saveButton.enabled, "pasted input must enable the save button");
}

static void TestInputWrapsAndGrowsToThreeLinesThenScrolls(void) {
    InputBarView *inputBar = [[InputBarView alloc] initWithFrame:NSMakeRect(0, 0, 320, 50)];
    inputBar.translatesAutoresizingMaskIntoConstraints = YES;
    [inputBar layoutSubtreeIfNeeded];

    NSTextView *textView = [inputBar valueForKey:@"textField"];
    NSScrollView *scrollView = [inputBar valueForKey:@"textScrollView"];
    CGFloat singleLineHeight = inputBar.intrinsicContentSize.height;

    textView.string = [@"" stringByPaddingToLength:35 withString:@"较长内容需要自动换行" startingAtIndex:0];
    [inputBar textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification object:textView]];
    [inputBar layoutSubtreeIfNeeded];
    CGFloat wrappedHeight = inputBar.intrinsicContentSize.height;

    textView.string = [@"" stringByPaddingToLength:120 withString:@"较长内容需要自动换行" startingAtIndex:0];
    [inputBar textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification object:textView]];
    [inputBar layoutSubtreeIfNeeded];

    CGFloat lineHeight = ceil([textView.layoutManager defaultLineHeightForFont:textView.font]);
    AssertTrue(wrappedHeight > singleLineHeight, "input must grow when long content wraps onto additional lines");
    AssertTrue(NSHeight(scrollView.frame) <= (lineHeight * 3.0) + 4.5,
               "input text viewport must be capped at three lines");
    AssertTrue(scrollView.hasVerticalScroller, "input must enable internal scrolling after three lines");
    AssertTrue(NSHeight(textView.frame) > NSHeight(scrollView.contentView.bounds),
               "overflowing input text must remain available inside the scrollable document");
    AssertTrue(!scrollView.hasHorizontalScroller && textView.textContainer.widthTracksTextView,
               "input content must wrap instead of scrolling horizontally");
}

static void TestWindowAppliesGrowingInputIntrinsicHeight(void) {
    [NSApplication sharedApplication];
    ReminderStore *store = [[ReminderStore alloc] initWithStorageURL:TemporaryStoreURL()];
    ReminderWindowController *controller = [[ReminderWindowController alloc] initWithStore:store];
    InputBarView *inputBar = [controller valueForKey:@"inputBar"];
    NSTextView *textView = [inputBar valueForKey:@"textField"];
    [controller.window.contentView layoutSubtreeIfNeeded];
    CGFloat initialHeight = NSHeight(inputBar.frame);

    textView.string = [@"" stringByPaddingToLength:120 withString:@"输入框应随自动换行增加高度" startingAtIndex:0];
    [inputBar textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification object:textView]];
    [controller.window.contentView layoutSubtreeIfNeeded];
    [controller.window.contentView layoutSubtreeIfNeeded];

    AssertTrue(NSHeight(inputBar.frame) > initialHeight,
               "window layout must apply the input bar's growing intrinsic height");
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

static NSTextView *FindTextView(NSView *view) {
    if ([view isKindOfClass:NSTextView.class]) {
        return (NSTextView *)view;
    }
    for (NSView *subview in view.subviews) {
        NSTextView *textView = FindTextView(subview);
        if (textView) {
            return textView;
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

    NSTextView *textField = FindTextView(row);

    AssertTrue(textField != nil, "row must render item content in a text view");
    AssertEqualObjects(textField.string, @"copy partial text", "row text view must show item content");
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

    NSTextView *textField = FindTextView(row);
    AssertTrue(textField != nil, "row must render item content in a text view before copy");

    [window makeFirstResponder:textField];
    textField.selectedRange = NSMakeRange(5, 7);

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

static void TestSavedContentWrapsToThreeLinesThenScrolls(void) {
    ReminderItem *item = [[ReminderItem alloc] initWithItemID:@"row-long"
                                                   categoryID:@"work"
                                                      content:[@"" stringByPaddingToLength:140
                                                                                     withString:@"已添加的较长内容需要自动换行"
                                                                                startingAtIndex:0]
                                                    createdAt:[NSDate dateWithTimeIntervalSince1970:0]];
    ReminderCategory *category = [ReminderCategory.defaultCategories firstObject];
    ReminderRowView *row = [[ReminderRowView alloc] initWithItem:item category:category];
    row.translatesAutoresizingMaskIntoConstraints = YES;
    row.frame = NSMakeRect(0, 0, 360, 66);
    [row layoutSubtreeIfNeeded];
    [row layoutSubtreeIfNeeded];

    NSTextView *textView = FindTextView(row);
    NSScrollView *scrollView = [row valueForKey:@"contentScrollView"];
    NSLayoutConstraint *rowHeightConstraint = [row valueForKey:@"rowHeightConstraint"];
    CGFloat lineHeight = ceil([textView.layoutManager defaultLineHeightForFont:textView.font]);

    AssertTrue(rowHeightConstraint.constant > 66.0, "multi-line saved content must increase its row height");
    AssertTrue(NSHeight(scrollView.frame) <= (lineHeight * 3.0) + 4.5,
               "saved content viewport must be capped at three lines");
    AssertTrue(scrollView.hasVerticalScroller, "saved content must scroll inside its row after three lines");
    AssertTrue(NSHeight(textView.frame) > NSHeight(scrollView.contentView.bounds),
               "all saved content must remain reachable inside the row scroller");
    AssertTrue(!scrollView.hasHorizontalScroller && textView.textContainer.widthTracksTextView,
               "saved content must wrap instead of being truncated horizontally");
}

static void TestRowWheelEventsReachTheListScroller(void) {
    [NSApplication sharedApplication];
    ReminderRecordingScrollView *listScrollView = [[ReminderRecordingScrollView alloc] initWithFrame:NSMakeRect(0, 0, 480, 300)];
    NSView *documentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 480, 600)];
    listScrollView.documentView = documentView;

    ReminderItem *item = [[ReminderItem alloc] initWithItemID:@"row-wheel"
                                                   categoryID:@"quickCommand"
                                                      content:@"git status"
                                                    createdAt:[NSDate dateWithTimeIntervalSince1970:0]];
    ReminderCategory *category = CategoryWithIdentifier(@"quickCommand");
    ReminderRowView *row = [[ReminderRowView alloc] initWithItem:item category:category];
    row.translatesAutoresizingMaskIntoConstraints = YES;
    row.frame = NSMakeRect(20, 500, 440, 66);
    [documentView addSubview:row];
    [row layoutSubtreeIfNeeded];

    NSTextView *textView = FindTextView(row);
    NSScrollView *contentScrollView = [row valueForKey:@"contentScrollView"];
    NSEvent *event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                        location:NSZeroPoint
                                   modifierFlags:0
                                       timestamp:0
                                    windowNumber:0
                                         context:nil
                                         subtype:0
                                           data1:0
                                           data2:0];

    AssertTrue(!contentScrollView.hasVerticalScroller, "single-line row must not reserve an internal scrolling target");
    [textView scrollWheel:event];
    AssertTrue(listScrollView.receivedScrollWheelEvents == 1,
               "wheel events over row text must reach the list scroller");
    [row scrollWheel:event];
    AssertTrue(listScrollView.receivedScrollWheelEvents == 2,
               "wheel events over the row background must reach the list scroller");
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
    ReminderCategory *category = CategoryWithIdentifier(@"quickCommand");
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
    NSTextView *textField = [inputBar valueForKey:@"textField"];

    AssertTrue((controller.window.styleMask & NSWindowStyleMaskFullSizeContentView) != 0,
               "notes-style window must extend content into the titlebar");
    AssertTrue(controller.window.titleVisibility == NSWindowTitleHidden,
               "notes-style window must use a visually integrated titlebar");
    AssertTrue(controller.window.minSize.width >= 700.0,
               "two-column layout must keep a usable minimum width");
    NSRect defaultContentRect = [controller.window contentRectForFrameRect:controller.window.frame];
    AssertTrue(fabs(NSWidth(defaultContentRect) - 1280.0) <= 0.5 &&
               fabs(NSHeight(defaultContentRect) - 800.0) <= 0.5,
               "default window content size must be 1280 by 800");
    AssertEqualObjects(categoryTitle.stringValue, @"工作", "main header must show the active folder");
    AssertEqualObjects(itemCount.stringValue, @"0 条备忘", "main header must show the empty item count");
    AssertTrue(!emptyState.hidden, "empty folder must show an empty-state explanation");
    NSAttributedString *placeholder = [textField valueForKey:@"placeholderAttributedString"];
    AssertTrue([placeholder.string containsString:@"工作"],
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
    ReminderCategory *category = CategoryWithIdentifier(@"quickCommand");
    ReminderRowView *row = [[ReminderRowView alloc] initWithItem:item category:category];
    NSTextView *textField = FindTextView(row);

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

static void TestSidebarSupportsRaycastAndCategoryManagement(void) {
    [NSApplication sharedApplication];
    ReminderStore *store = [[ReminderStore alloc] initWithStorageURL:TemporaryStoreURL()];
    ReminderWindowController *controller = [[ReminderWindowController alloc] initWithStore:store];
    CategoryTabView *tabView = [controller valueForKey:@"tabView"];
    NSDictionary *buttons = [tabView valueForKey:@"buttonsByCategory"];
    NSButton *raycastButton = buttons[@"raycastCommand"];
    NSButton *workButton = buttons[@"work"];
    NSButton *addButton = [tabView valueForKey:@"addCategoryButton"];

    AssertTrue(raycastButton != nil, "sidebar must show the default Raycast command category");
    AssertEqualObjects([raycastButton valueForKey:@"categoryDisplayName"], @"Raycast命令",
                       "Raycast command category must use the requested display name");
    AssertEqualObjects(addButton.title, @"新建栏目", "sidebar must provide a bottom add-category button");
    AssertEqualObjects([workButton.menu.itemArray valueForKey:@"title"], (@[@"重命名…", @"移除…"]),
                       "right-click category menu must provide rename and remove actions");

    __block BOOL addTriggered = NO;
    __block NSString *renamedCategoryID = nil;
    __block NSString *removedCategoryID = nil;
    tabView.onAddCategory = ^{ addTriggered = YES; };
    tabView.onRenameCategory = ^(NSString *categoryID) { renamedCategoryID = categoryID; };
    tabView.onRemoveCategory = ^(NSString *categoryID) { removedCategoryID = categoryID; };

    [addButton performClick:nil];
    [NSApp sendAction:workButton.menu.itemArray[0].action
                    to:workButton.menu.itemArray[0].target
                  from:workButton.menu.itemArray[0]];
    [NSApp sendAction:workButton.menu.itemArray[1].action
                    to:workButton.menu.itemArray[1].target
                  from:workButton.menu.itemArray[1]];

    AssertTrue(addTriggered, "add-category button must trigger its handler");
    AssertEqualObjects(renamedCategoryID, @"work", "rename menu item must identify its category");
    AssertEqualObjects(removedCategoryID, @"work", "remove menu item must identify its category");
}

int main(void) {
    @autoreleasepool {
        TestListDocumentViewUsesTopOrigin();
        TestInputPlaceholderUsesTwentyPointInsetAndVerticalCenter();
        TestInputCommandVPastesClipboardText();
        TestInputWrapsAndGrowsToThreeLinesThenScrolls();
        TestWindowAppliesGrowingInputIntrinsicHeight();
        TestRowTextIsSelectableButNotEditable();
        TestRowTextCommandCCopiesSelectedText();
        TestSavedContentWrapsToThreeLinesThenScrolls();
        TestRowWheelEventsReachTheListScroller();
        TestQuickCommandCopyShowsSuccessToast();
        TestQuickCommandCopyButtonHasPressedTextFeedback();
        TestNotesStyleWindowAndEmptyState();
        TestSaveAndDeleteUpdateSummaryAndFeedback();
        TestRowsUseNotesStyleHeightAndCommandTypography();
        TestThemeFollowsLightAndDarkAppearance();
        TestSidebarUsesFullWidthAlignment();
        TestSidebarSupportsRaycastAndCategoryManagement();

        if (gFailures > 0) {
            NSLog(@"%lu layout test failure(s)", (unsigned long)gFailures);
            return 1;
        }

        NSLog(@"All Objective-C layout tests passed");
        return 0;
    }
}
