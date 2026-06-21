#import <AppKit/AppKit.h>
#import <math.h>
#import "../Sources/Store/ReminderStore.h"
#import "../Sources/Views/InputBarView.h"
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
    InputBarView *inputBar = [[InputBarView alloc] initWithFrame:NSMakeRect(0, 0, 320, 104)];
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
    InputBarView *inputBar = [[InputBarView alloc] initWithFrame:NSMakeRect(0, 0, 320, 104)];
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

int main(void) {
    @autoreleasepool {
        TestListDocumentViewUsesTopOrigin();
        TestInputPlaceholderUsesTwentyPointInsetAndVerticalCenter();
        TestInputCommandVPastesClipboardText();

        if (gFailures > 0) {
            NSLog(@"%lu layout test failure(s)", (unsigned long)gFailures);
            return 1;
        }

        NSLog(@"All Objective-C layout tests passed");
        return 0;
    }
}
