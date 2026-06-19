#import "AppDelegate.h"
#import "Store/ReminderStore.h"
#import "Views/ReminderWindowController.h"

@interface AppDelegate ()
@property (nonatomic, strong) ReminderStore *store;
@property (nonatomic, strong) ReminderWindowController *windowController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [self setupMainMenu];

    self.store = [[ReminderStore alloc] initWithStorageURL:ReminderStore.defaultStorageURL];
    self.windowController = [[ReminderWindowController alloc] initWithStore:self.store];
    [self.windowController showAndFocus];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    (void)sender;
    (void)flag;
    [self.windowController showAndFocus];
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self.store flushSync];
}

- (void)setupMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:appMenuItem];

    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Reminder"];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Reminder"
                                                      action:@selector(terminate:)
                                               keyEquivalent:@"q"];
    [appMenu addItem:quitItem];
    appMenuItem.submenu = appMenu;
    NSApp.mainMenu = mainMenu;
}

@end
