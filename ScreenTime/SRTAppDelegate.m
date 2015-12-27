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

@interface SRTAppDelegate ()
@property (nonatomic, strong) SRTScreenShooter *screenShooter;
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
    
    NSImage *iconImage = [NSImage imageNamed:@"ScreenTime"];
    iconImage.template = YES;
    
    self.versionMenuItem.title = [NSString stringWithFormat:@"Version %@", currentVersionString];
    
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.image = iconImage;
    _statusItem.highlightMode = YES;
    _statusItem.toolTip = [NSString stringWithFormat:@"ScreenTime %@", currentVersionString];
    _statusItem.menu = _menu;
    
    [_historyDepthSlider setTarget:self];
    [_historyDepthSlider setAction:@selector(historySliderDidMove:)];
    
    _historyDepthSlider.allowsTickMarkValuesOnly = YES;
    _historyDepthSlider.maxValue = 4;
    _historyDepthSlider.numberOfTickMarks = 5;
    
    [self updateHistoryDepthLabelDescription];
    [self updateHistoryDepthSliderPosition];

    [self.historyDepthMenuItem setView:_historyDepthView];
    
    [_menu setDelegate:self];
    
    /**/
    
    [self startTimer];
    
    /**/
    
    [self updateStartAtLaunchMenuItemState];
    
    [self updateSkipScreensaverMenuItemState];
    
    [self updatePauseCaptureMenuItemState];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self stopTimer];
}

- (void)startTimer {
    NSLog(@"-- startTimer");
    
    self.screenShooter = [[SRTScreenShooter alloc] initWithDirectory:_dirPath];
    if(_screenShooter == nil) {
        NSLog(@"-- cannot use screenshooter, exit");
        exit(1); // TODO: show NSAlert?
    }
    
    [_screenShooter makeScreenshotsAndConsolidate];
    
    NSUInteger timeInterval = [[NSUserDefaults standardUserDefaults] integerForKey:@"SecondsBetweenScreenshots"];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:timeInterval
                                                  target:_screenShooter
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

- (void)updateStartAtLaunchMenuItemState {
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
    
    [self updateStartAtLaunchMenuItemState];
}

- (void)checkForUpdates {
    
    NSURL *url = [NSURL URLWithString:@"http://www.seriot.ch/screentime/screentime.json"];
    
    [[[NSURLSession sharedSession] dataTaskWithURL:url
                                 completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                     
                                     if(data == nil) {
                                         NSLog(@"-- %@", [error localizedDescription]);
                                         return;
                                     }
                                     
                                     NSError *jsonError = nil;
                                     NSDictionary *d = [NSJSONSerialization JSONObjectWithData:data
                                                                                       options:NSJSONReadingMutableContainers
                                                                                         error:&jsonError];
                                     
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
                                     
                                     NSModalResponse modalResponse = [alert runModal];
                                     
                                     if(modalResponse == NSAlertFirstButtonReturn) {
                                         NSURL *downloadURL = [NSURL URLWithString:latestVersionURL];
                                         [[NSWorkspace sharedWorkspace] openURL:downloadURL];
                                     }
                                     
                                 }] resume];
}

- (IBAction)togglePause:(id)sender {
    BOOL captureWasPaused = self.timer == nil;
    
    if(captureWasPaused) {
        [self startTimer];
    } else {
        [self stopTimer];
    }
    
    NSString *imageName = captureWasPaused ? @"ScreenTime" : @"ScreenTimePaused";
    NSImage *iconImage = [NSImage imageNamed:imageName];
    iconImage.template = YES;
    self.statusItem.image = iconImage;
    
    [self updatePauseCaptureMenuItemState];
}

- (IBAction)quit:(id)sender {
    [[NSApplication sharedApplication] terminate:self];
}

+ (NSInteger)sliderValueForNumberOfDays:(NSUInteger)numberOfDays {
    if(numberOfDays == 1) return 0;
    if(numberOfDays == 30) return 1;
    if(numberOfDays == 90) return 2;
    if(numberOfDays == 360) return 3;
    if(numberOfDays == 0) return 4;
    return 0;
}

+ (NSUInteger)historyNumberOfDaysForSliderValue:(NSInteger)value {
    if(value < 0) return 0;
    if(value == 0) return 1;
    if(value == 1) return 30;
    if(value == 2) return 90;
    if(value == 3) return 360;
    if(value == 4) return 0;
    return 0;
}

+ (NSString *)historyPeriodDescriptionForSliderValue:(NSInteger)value {
    NSUInteger i = [self historyNumberOfDaysForSliderValue:value];
    
    if(i == 0) return @"Never";
    if(i == 1) return @"1 day";
    
    return [NSString stringWithFormat:@"%@ days", @(i)];
}

- (IBAction)historySliderDidMove:(NSSlider *)slider {
    
    NSInteger sliderValue = [slider integerValue];
    
    NSLog(@"** %@", @(sliderValue));
    
    NSString *s = [[self class] historyPeriodDescriptionForSliderValue:sliderValue];
    
    [_historyDepthTextField setStringValue:s];
    
    NSUInteger numberOfDays = [[self class] historyNumberOfDaysForSliderValue:sliderValue];
    
    [[NSUserDefaults standardUserDefaults] setInteger:numberOfDays forKey:@"HistoryToKeepInDays"];
}

- (void)updateHistoryDepthLabelDescription {

    NSUInteger numberOfDays = [[NSUserDefaults standardUserDefaults] integerForKey:@"HistoryToKeepInDays"];

    NSUInteger sliderValue = [[self class] sliderValueForNumberOfDays:numberOfDays];

    NSString *s = [[self class] historyPeriodDescriptionForSliderValue:sliderValue];
    
    [_historyDepthTextField setStringValue:s];
}

- (void)updateHistoryDepthSliderPosition {

    NSUInteger numberOfDays = [[NSUserDefaults standardUserDefaults] integerForKey:@"HistoryToKeepInDays"];

    _historyDepthSlider.integerValue = [[self class] sliderValueForNumberOfDays:numberOfDays];
}

#pragma mark NSMenuDelegate

- (void)menuWillOpen:(NSMenu *)menu {
    
    [self updateStartAtLaunchMenuItemState];
    
    NSEventModifierFlags modifierFlags = [[NSApp currentEvent] modifierFlags];
    BOOL optionKeyIsPressed = (modifierFlags & kCGEventFlagMaskAlternate) == kCGEventFlagMaskAlternate;
    BOOL commandKeyIsPressed = (modifierFlags & kCGEventFlagMaskCommand) == kCGEventFlagMaskCommand;
    
    if(optionKeyIsPressed && commandKeyIsPressed) {
        [_screenShooter makeScreenshotsAndConsolidate];
    }
    
    [self.versionMenuItem setHidden:(optionKeyIsPressed == NO)];
}

@end
