//
//  AppDelegate.m
//  Spotify Notifications
//

#import "AppDelegate.h"
#import "GBLaunchAtLogin.h"
#import "MASShortcutView.h"
#import "MASShortcutView+UserDefaults.h"
#import "MASShortcut+UserDefaults.h"
#import "MASShortcut+Monitoring.h"
#import "SNXTrack.h"

@implementation AppDelegate

@synthesize statusBar;
@synthesize statusMenu;
@synthesize openPrefences;
@synthesize soundToggle;
@synthesize window;
@synthesize iconToggle;
@synthesize startupToggle;
@synthesize showTracksToggle;
@synthesize shortcutView;

BOOL *UserNotificationContentImagePropertyAvailable;

SNXTrack *track;

NSString *previousTrack;

- (void)applicationDidFinishLaunching:(NSNotification *)notification {

    SInt32 OSXversionMajor, OSXversionMinor;

    if (Gestalt(gestaltSystemVersionMajor, &OSXversionMajor) == noErr && Gestalt(gestaltSystemVersionMinor, &OSXversionMinor) == noErr) {

        if(OSXversionMajor == 10 && OSXversionMinor >= 9) {
      
            UserNotificationContentImagePropertyAvailable = YES;  

        }

        else {

            UserNotificationContentImagePropertyAvailable = NO;

        }

    }
    
    track = [[SNXTrack alloc] init];
    
    previousTrack = @"";
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(eventOccured:)
                                                            name:@"com.spotify.client.PlaybackStateChanged"
                                                          object:nil
                                              suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    
    [self setIcon];
    [self setupGlobalShortcutForNotifications];
    
    [soundToggle selectItemAtIndex:[self getProperty:@"notificationSound"]];
    [iconToggle selectItemAtIndex:[self getProperty:@"iconSelection"]];
    [startupToggle selectItemAtIndex:[self getProperty:@"startupSelection"]];
    [showTracksToggle selectItemAtIndex:[self getProperty:@"showTracks"]];
    
    if ([self getProperty:@"startupSelection"] == 0) {
        
        [GBLaunchAtLogin addAppAsLoginItem];
        
    }
    
    if ([self getProperty:@"startupSelection"] == 1) {
        
        [GBLaunchAtLogin removeAppFromLoginItems];
        
    }

}

- (void)setupGlobalShortcutForNotifications {
    
    NSString *const kPreferenceGlobalShortcut = @"ShowCurrentTrack";
    self.shortcutView.associatedUserDefaultsKey = kPreferenceGlobalShortcut;
    
    [MASShortcut registerGlobalShortcutWithUserDefaultsKey:kPreferenceGlobalShortcut handler:^{
        
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = track.title;
        notification.subtitle = track.album;
        notification.informativeText = track.artist;
        
        if ((UserNotificationContentImagePropertyAvailable) &&
            (track.albumArt)) {
            
            notification.contentImage = track.albumArt;
            
        }
        
        if ([self getProperty:@"notificationSound"] == 0) {
            
            notification.soundName = NSUserNotificationDefaultSoundName;
            
        }
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        track.albumArt = nil;
        
    }];
    
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {

    if (!flag) {
        
        // This makes it so you can open the preferences by re-opening the app
        // This way you can get to the preferences even when the status item is hidden
        [self showPrefences:nil];
        
    }
    
    return YES;
    
}

- (IBAction)showSource:(id)sender {

    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"http://github.com/citruspi/Spotify-Notifications"]];

}

- (IBAction)showHome:(id)sender {

    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"http://mihirsingh.com/Spotify-Notifications"]];

}

- (IBAction)showAuthor:(id)sender {
    
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"http://mihirsingh.com"]];
    
}

- (IBAction)showPrefences:(id)sender {
    
    [NSApp activateIgnoringOtherApps:YES];
    [window makeKeyAndOrderFront:nil];
    
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
    shouldPresentNotification:(NSUserNotification *)notification {
    
    return YES;
    
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {

    NSLog(@"Clicked");
    [[NSWorkspace sharedWorkspace] launchApplication:@"Spotify"];
    
}

- (void)eventOccured:(NSNotification *)notification {
        
    NSDictionary *information = [notification userInfo];
    
    if ([[information objectForKey: @"Player State"]isEqualToString:@"Playing"]) {
        
        track.artist = [information objectForKey: @"Artist"];
        track.album = [information objectForKey: @"Album"];
        track.title = [information objectForKey: @"Name"];        
        track.trackID = [information objectForKey:@"Track ID"];
        
        if (![previousTrack isEqualToString:track.trackID] || [self getProperty:@"showTracks"] == 0) {
            
            previousTrack = track.trackID;
            track.albumArt = nil;
        
            NSUserNotification *notification = [[NSUserNotification alloc] init];
            notification.title = track.title;
            notification.subtitle = track.album;
            notification.informativeText = track.artist;
            
            if (UserNotificationContentImagePropertyAvailable) {

                [track fetchAlbumArt];
                notification.contentImage = track.albumArt;

            }
            
            if ([self getProperty:@"notificationSound"] == 0) {

                notification.soundName = NSUserNotificationDefaultSoundName;

            }

            [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
            
        }
    }
    
}

- (IBAction)toggleSound:(id)sender {
    
    [self saveProperty:@"notificationSound" :(int)[soundToggle indexOfSelectedItem]];
    
}

- (IBAction)toggleShowTracks:(id)sender {
    
    [self saveProperty:@"showTracks" :(int)[showTracksToggle indexOfSelectedItem]];
    
}

- (IBAction)toggleStartup:(id)sender {
    
    [self saveProperty:@"startupSelection" :(int)[startupToggle indexOfSelectedItem]];
    
    if ([self getProperty:@"startupSelection"] == 0) {
        
        [GBLaunchAtLogin addAppAsLoginItem];
        
    }
    
    if ([self getProperty:@"startupSelection"] == 1) {
        
        [GBLaunchAtLogin removeAppFromLoginItems];
        
    }

}

- (void)setIcon {
    
    if ([self getProperty:@"iconSelection"] == 0) {
        
        self.statusBar = nil;
        self.statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
        self.statusBar.image = [NSImage imageNamed:@"status_bar_colour.tiff"];
        self.statusBar.menu = self.statusMenu;
        self.statusBar.highlightMode = YES;
        
    }
    
    if ([self getProperty:@"iconSelection"] == 1) {
        
        self.statusBar = nil;
        self.statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
        self.statusBar.image = [NSImage imageNamed:@"status_bar_black.tiff"];
        self.statusBar.menu = self.statusMenu;
        self.statusBar.highlightMode = YES;
        
    }
    
    if ([self getProperty:@"iconSelection"] == 2) {

        self.statusBar = nil;
        
    }
    
}

- (IBAction)toggleIcons:(id)sender {
    
    [self saveProperty:@"iconSelection" :(int)[iconToggle indexOfSelectedItem]];
    [self setIcon];
    
}

- (void)saveProperty:(NSString*)key:(int)value {
    
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
	if (standardUserDefaults) {
        
		[standardUserDefaults setInteger:value forKey:key];
		[standardUserDefaults synchronize];
        
	}
    
}

- (Boolean)getProperty:(NSString*)key {

	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
	int val = 0;
    
	if (standardUserDefaults) {
	
        val = (int)[standardUserDefaults integerForKey:key];

    }
    
	return val;
    
}

@end