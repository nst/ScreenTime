//
//  SRTScreenShooter.m
//  ScreenTime
//
//  Created by Nicolas Seriot on 26/06/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

#import "SRTScreenShooter.h"
#import "SRTMovieMaker.h"
#import "SRTConsolidator.h"
#import "NSImage+SRT.h"
#import "NSDate+SRT.h"

@implementation SRTScreenShooter

- (instancetype)initWithDirectory:(NSString *)path {
    self = [super init];
    
    BOOL isDir = NO;
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    if(fileExists == NO || isDir == NO) {
        // NSLog(@"-- error: not a directory: %@", path);
        
        NSError *error = nil;
        BOOL isDirCreated = [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        if(isDirCreated) {
            NSLog(@"-- created %@", path);
        } else {
            NSLog(@"-- error, cannot create %@, %@", path, [error localizedDescription]);
            return nil;
        }
    }
    
    self.directoryPath = path;
    return self;
}

- (NSImage *)takeScreenshotForDisplayID:(CGDirectDisplayID)displayID {
    CGImageRef imageRef = CGDisplayCreateImage(displayID);
    NSImage *image = [[NSImage alloc] initWithCGImage:imageRef size:NSZeroSize];
    CGImageRelease(imageRef);
    return image;
}

- (BOOL)writeScreenshot:(NSImage *)image displayIDForFilename:(NSString *)displayIDForFilename {
    
    NSString *timestamp = [[NSDate date] srt_timestamp];
    
    NSString *filename = timestamp;
    
    if(displayIDForFilename) {
        filename = [filename stringByAppendingFormat:@"_%@", displayIDForFilename];
    }
    
    filename = [filename stringByAppendingPathExtension:@"jpg"];
    
    NSString *path = [_directoryPath stringByAppendingPathComponent:filename];
    
    BOOL success = [image srt_writeAsJpegAtPath:path];
    
    if(success) {
        NSLog(@"-- write %@", path);
    } else {
        NSLog(@"-- can't write %@", path);
    }
    
    return success;
}

- (BOOL)isRunningScreensaver {
    
    NSArray *runningApplications = [[NSWorkspace sharedWorkspace] runningApplications];
    
    for(NSRunningApplication *app in runningApplications) {
        if([[app bundleIdentifier] hasPrefix:@"com.apple.ScreenSaver"]) return YES;
    }
    
    return NO;
}

- (void)makeScreenshotsAndConsolidate {
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"SkipScreensaver"] && [self isRunningScreensaver]) {
        NSLog(@"-- ignore screensaver");
        return;
    }
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"PauseCapture"]) {
        NSLog(@"-- capture pause prevented screenshot");
        return;
    }
    
    static const uint32_t MAX_DISPLAYS = 16;
    
    CGDisplayCount displayCount;
    CGDirectDisplayID displays[MAX_DISPLAYS];
    
    CGError status = CGGetActiveDisplayList(MAX_DISPLAYS, displays, &displayCount);
    
    if(status != kCGErrorSuccess) {
        NSLog(@"-- cannot get active display list, error %d", status);
        return;
    }
    
    for (int i = 0; i < displayCount; i++) {
        CGDirectDisplayID displayID = displays[i];
        NSImage *image = [self takeScreenshotForDisplayID:displayID];
        NSString *displayIDForFilename = [NSString stringWithFormat:@"%@", @(displayID)];
        [self writeScreenshot:image displayIDForFilename:displayIDForFilename];
    }
    
    SRTConsolidator *c = [SRTConsolidator consolidatorWithDirPath:_directoryPath];

    NSUInteger historyToKeepInDays = [[NSUserDefaults standardUserDefaults] integerForKey:@"HistoryToKeepInDays"];
    if(historyToKeepInDays > 0) {
        [c removeFilesOlderThanNumberOfDays:historyToKeepInDays];
    }

    [c consolidateHourMoviesIntoDayMovies];
    
    [c consolidateScreenshotsIntoHourMovies];
}

@end
