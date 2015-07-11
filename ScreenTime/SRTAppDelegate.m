//
//  AppDelegate.m
//  ScreenTime
//
//  Created by Nicolas Seriot on 26/06/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

#import "SRTAppDelegate.h"
#import "SRTScreenShooter.h"
#import "SRTLoginItems.h"
#import "STHTTPRequest.h"

@interface SRTAppDelegate ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSString *dirPath;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation SRTAppDelegate

- (BOOL)ensureThatDirectoryExistsByCreatingOneIfNeeded:(NSString *)path {
    
    BOOL isDir = NO;
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    
    if(fileExists) return isDir;
    
    // create file
    NSError *error = nil;
    BOOL isDirCreated = [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
    if(isDirCreated == NO) {
        NSLog(@"-- error, cannot create %@, %@", path, [error localizedDescription]);
        return NO;
    }
    
    NSLog(@"-- created %@", path);
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    NSDictionary *appDefaults = @{@"SecondsBetweenScreenshots":@(60),
                                  @"FramesPerSecond":@(2)};
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
    
    /**/
    
    self.dirPath = [@"~/Library/ScreenTime" stringByExpandingTildeInPath];
    BOOL dirExists = [self ensureThatDirectoryExistsByCreatingOneIfNeeded:_dirPath];
    if(dirExists == NO) {
        NSLog(@"-- cannot create %@", _dirPath);
        return; // TODO: show NSAlert
    }
    
    NSString *currentVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    
    NSImage *iconImage = [NSImage imageNamed:@"ScreenTime.png"];
    iconImage.template = YES;
    
    _aboutScreenTimeMenuItem.title = [NSString stringWithFormat:@"About ScreenTime %@", currentVersionString];
    
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.image = iconImage;
    _statusItem.highlightMode = YES;
    _statusItem.toolTip = [NSString stringWithFormat:@"ScreenTime %@", currentVersionString];
    _statusItem.menu = _menu;
    
    [_menu setDelegate:self];
    
    /**/

    [self startTimer];

    /**/
    
    [self updateStartAtLauchMenuItemState];
    
    [self updateSkipScreensaverMenuItemState];
    
    [self updatePauseCaptureMenuItemState];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self stopTimer];
}

- (void)startTimer {
    NSLog(@"-- startTimer");
    
    SRTScreenShooter *screenShooter = [[SRTScreenShooter alloc] initWithDirectory:_dirPath];
    if(screenShooter == nil) {
        NSLog(@"-- cannot use screenshooter, exit");
        exit(1); // TODO: show NSAlert?
    }
    
    [screenShooter makeScreenshotsAndConsolidate];
    
    NSUInteger timeInterval = [[NSUserDefaults standardUserDefaults] integerForKey:@"SecondsBetweenScreenshots"];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:timeInterval
                                                  target:screenShooter
                                                selector:@selector(makeScreenshotsAndConsolidate)
                                                userInfo:nil
                                                 repeats:YES];
    _timer.tolerance = 10;
    
    [self checkForUpdates];
}

- (void)stopTimer {
    NSLog(@"-- stopTimer");
    
    [_timer invalidate];
    self.timer = nil;
}

- (void)updateStartAtLauchMenuItemState {
    
    // TODO: refresh at each time the menu is opened
    
    BOOL startAtLogin = [SRTLoginItems loginItemIsEnabled];
    [_startAtLoginMenuItem setState: (startAtLogin ? NSOnState : NSOffState) ];
}

- (void)updateSkipScreensaverMenuItemState {
    BOOL skipScreensaver = [[NSUserDefaults standardUserDefaults] boolForKey:@"SkipScreensaver"];
    
    NSInteger state = skipScreensaver ? NSOnState : NSOffState;
    
    [_skipScreensaverMenuItem setState:state];
}

- (void)updatePauseCaptureMenuItemState {
    BOOL captureIsPaused = self.timer == nil;
    
    NSInteger state = captureIsPaused ? NSOnState : NSOffState;
    
    [_pauseCaptureMenuItem setState:state];
}

- (IBAction)about:(id)sender {
    NSURL *url = [NSURL URLWithString:@"http://seriot.ch/screentime/"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)openFolder:(id)sender {
    [[NSWorkspace sharedWorkspace] openFile:_dirPath];
}

- (IBAction)toggleSkipScreensaver:(id)sender {
    BOOL skipScreensaver = [[NSUserDefaults standardUserDefaults] boolForKey:@"SkipScreensaver"];
    
    [[NSUserDefaults standardUserDefaults] setBool:!skipScreensaver forKey:@"SkipScreensaver"];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self updateSkipScreensaverMenuItemState];
}

- (IBAction)toggleStartAtLogin:(id)sender {
    
    BOOL startAtLogin = [SRTLoginItems loginItemIsEnabled];
    
    if (startAtLogin) {
        [SRTLoginItems disableLoginItem];
    } else {
        [SRTLoginItems enableLoginItem];
    }
    
    [self updateStartAtLauchMenuItemState];
}

- (void)checkForUpdates {
    
    STHTTPRequest *r = [STHTTPRequest requestWithURLString:@"http://www.seriot.ch/screentime/screentime.json"];
    
    r.completionDataBlock = ^(NSDictionary *headers, NSData *data) {
        
        NSError *error = nil;
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:data
                                                          options:NSJSONReadingMutableContainers
                                                            error:&error];
        
        NSString *latestVersionString = d[@"latest_version_string"];
        NSString *latestVersionURL = d[@"latest_version_url"];
        
        NSLog(@"-- latestVersionString: %@", latestVersionString);
        NSLog(@"-- latestVersionURL: %@", latestVersionURL);
        
        NSString *currentVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        
        BOOL needsUpdate = [currentVersionString compare:latestVersionString] == NSOrderedAscending;
        
        NSLog(@"-- needsUpdate: %d", needsUpdate);
        if(needsUpdate == NO) return;
        
        NSString *messageText = [NSString stringWithFormat:@"ScreenTime %@ is Available", latestVersionString];
        NSString *infoText = @"Please download it and replace the current version.";
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = messageText;
        alert.informativeText = infoText;
        [alert addButtonWithTitle:@"Download"];
        [alert addButtonWithTitle:@"Cancel"];
        [alert setAlertStyle:NSInformationalAlertStyle];
        
        NSModalResponse response = [alert runModal];
        
        if(response == NSAlertFirstButtonReturn) {
            NSURL *downloadURL = [NSURL URLWithString:latestVersionURL];
            [[NSWorkspace sharedWorkspace] openURL:downloadURL];
        }
    };
    
    r.errorBlock = ^(NSError *error) {
        NSLog(@"-- %@", [error localizedDescription]);
    };
    
    [r startAsynchronous];
}

- (IBAction)togglePause:(id)sender {
    BOOL captureIsPaused = self.timer == nil;
    
    if(captureIsPaused) {
        [self startTimer];
    } else {
        [self stopTimer];
    }

    [self updatePauseCaptureMenuItemState];
}

- (IBAction)quit:(id)sender {
    [[NSApplication sharedApplication] terminate:self];
}

#pragma mark NSMenuDelegate

- (void)menuWillOpen:(NSMenu *)menu {
    [self updateStartAtLauchMenuItemState];
}

@end
