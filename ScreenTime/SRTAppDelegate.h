//
//  AppDelegate.h
//  ScreenTime
//
//  Created by Nicolas Seriot on 26/06/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SRTAppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>

@property (strong, nonatomic) IBOutlet NSMenu *menu;
@property (strong, nonatomic) IBOutlet NSMenuItem *aboutScreenTimeMenuItem;
@property (strong, nonatomic) IBOutlet NSMenuItem *skipScreensaverMenuItem;
@property (strong, nonatomic) IBOutlet NSMenuItem *startAtLoginMenuItem;
@property (strong, nonatomic) IBOutlet NSMenuItem *pauseCaptureMenuItem;

- (IBAction)about:(id)sender;
- (IBAction)openFolder:(id)sender;
- (IBAction)toggleSkipScreensaver:(id)sender;
- (IBAction)quit:(id)sender;

@end

