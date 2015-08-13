//
//  SRTConsolidator.m
//  ScreenTime
//
//  Created by Nicolas Seriot on 20/06/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

#import "SRTConsolidator.h"
#import "NSDate+SRT.h"
#import "SRTMovieMaker.h"
#import <AppKit/AppKit.h>

BOOL removeFiles(NSArray *paths) {
    for(NSString *path in paths) {
        NSLog(@"-- removing %@", path);
        NSError *error = nil;
        BOOL status = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
        if(status == NO) {
            NSLog(@"-- could not remove %@, error %@", path, [error localizedDescription]);
            return NO;
        }
    }
    return YES;
}

void writeMovieFromJpgPaths(NSString *dirPath, NSArray *jpgPaths, NSString *movieName, NSString *displayIDString, NSUInteger fps, void (^completionHandler)(NSString *)) {
    
    if([jpgPaths count] == 0) {
        NSLog(@"-- no screenshots to turn into movie");
    }
    
    // write movie
    
    NSString *fileName = [NSString stringWithFormat:@"%@_%@.mov", movieName, displayIDString];
    NSString *moviePath = [dirPath stringByAppendingPathComponent:fileName];
    
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:moviePath];
    if(fileExists) {
        NSError *error = nil;
        BOOL couldRemoveFile = [[NSFileManager defaultManager] removeItemAtPath:moviePath error:&error];
        if(couldRemoveFile == NO) {
            NSLog(@"-- error: cannot remove %@, %@", moviePath, [error localizedDescription]);
            return;
        }
    }
    
    NSImage *firstImage = [[NSImage alloc] initWithContentsOfFile:[jpgPaths firstObject]];
    
    SRTMovieMaker *movieMaker = [[SRTMovieMaker alloc] initWithPath:moviePath
                                                          frameSize:firstImage.size
                                                                fps:fps];
    
    if(movieMaker == nil) {
        NSLog(@"-- cannot instantiate SRTMovieMaker");
        return;
    }
    
    [jpgPaths enumerateObjectsUsingBlock:^(NSString *jpgPath, NSUInteger idx, BOOL *stop) {
        
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:jpgPath];
        
        NSArray *timestampAndDisplayID = [[[jpgPath lastPathComponent] stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
        
        NSString *timestamp = timestampAndDisplayID[0];
        
        NSString *formattedDate = [NSDate srt_prettyDateFromTimestamp:timestamp];
        
        [movieMaker appendImageFromDrawing:^(CGContextRef context) {
            
            // draw image
            CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
            [image drawInRect:rect];
            
            // draw string frame
            CGFloat STRING_RECT_ORIGIN_X = rect.size.width - 320;
            CGFloat STRING_RECT_ORIGIN_Y = 32;
            CGFloat STRING_RECT_WIDTH = 300;
            CGFloat STRING_RECT_HEIGHT = 54;
            CGRect stringRect = CGRectMake(STRING_RECT_ORIGIN_X, STRING_RECT_ORIGIN_Y, STRING_RECT_WIDTH, STRING_RECT_HEIGHT);
            
            [[NSColor whiteColor] setFill];
            [[NSColor blackColor] setStroke];
            NSRectFill(stringRect);
            [NSBezierPath strokeRect:stringRect];
            
            // draw string
            NSDictionary *attributes = @{NSFontAttributeName:[NSFont fontWithName:@"Courier" size:24],
                                         NSForegroundColorAttributeName:[NSColor blueColor]};
            
            NSAttributedString *s = [[NSAttributedString alloc] initWithString:[formattedDate lastPathComponent]
                                                                    attributes:attributes];
            [s drawAtPoint:CGPointMake(STRING_RECT_ORIGIN_X + 16, STRING_RECT_ORIGIN_Y + 16)];
        }];
    }];
    
    [movieMaker endWritingMovieWithWithCompletionHandler:^(NSString *path) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(path);
        });
        
    }];
}

/*
 consolidate past assets
 
 for each past day
 ...make hour movie from day images
 ...make day movie from hour movies
 
 for each today past hour
 ...make hour movie
 */

@interface SRTConsolidator ()
@property (nonatomic, strong) NSString *dirPath;
@end

@implementation SRTConsolidator

+ (instancetype)consolidatorWithDirPath:(NSString *)dirPath {
    SRTConsolidator *c = [[SRTConsolidator alloc] init];
    
    c.dirPath = dirPath;
    
    return c;
}

+ (NSArray *)filterFilenames:(NSArray *)paths
               directoryPath:(NSString *)dirPath
                     withExt:(NSString *)ext
             timestampLength:(NSUInteger)timestampLength
                beforeString:(NSString *)beforeString
     groupedByPrefixOfLength:(NSUInteger)groupPrefixLength {
    
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSString *path, NSDictionary *bindings) {
        if([[[path pathExtension] lowercaseString] isEqualToString:[ext lowercaseString]] == NO) return NO;
        NSString *filename = [[path lastPathComponent] stringByDeletingPathExtension];
        NSArray *components = [filename componentsSeparatedByString:@"_"];
        if([components count] != 2) return NO;
        NSString *timestamp = components[0];
        if([timestamp length] != timestampLength) return NO;
        return [beforeString compare:filename] == NSOrderedDescending;
    }];
    
    NSArray *filteredPaths = [paths filteredArrayUsingPredicate:predicate];
    
    /**/
    
    NSMutableDictionary *groupDictionary = [NSMutableDictionary dictionary];
    
    for(NSString *path in filteredPaths) {
        NSString *prefix = [[path lastPathComponent] substringToIndex:groupPrefixLength]; // timestamp
        NSString *suffix = [[[[path lastPathComponent] stringByDeletingPathExtension] componentsSeparatedByString:@"_"] lastObject]; // displayID
        NSString *key = [NSString stringWithFormat:@"%@_%@", prefix, suffix];
        
        if(groupDictionary[key] == nil) groupDictionary[key] = [NSMutableArray array];
        NSMutableArray *group = groupDictionary[key];
        NSString *fullPath = [dirPath stringByAppendingPathComponent:path];
        [group addObject:fullPath];
    }
    
    NSArray *sortedKeys = [[groupDictionary allKeys] sortedArrayUsingSelector:@selector(compare:)];
    
    NSMutableArray *groups = [NSMutableArray array];
    
    for(NSString *key in sortedKeys) {
        [groups addObject:groupDictionary[key]];
    }
    
    return groups;
}

// hour movies -> day movies
- (void)consolidateHourMoviesIntoDayMovies {
    
    NSString *today = [[[NSDate date] srt_timestamp] substringToIndex:8];
    
    NSArray *filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_dirPath
                                                                             error:NULL];
    
    NSArray *hourMoviesArrays = [[self class] filterFilenames:filenames
                                                directoryPath:_dirPath
                                                      withExt:@"mov"
                                              timestampLength:10
                                                 beforeString:today
                                      groupedByPrefixOfLength:8];
    
    for(NSArray *hourMovies in hourMoviesArrays) {
        
        NSArray *timestampAndDisplayID = [[[[hourMovies firstObject] lastPathComponent] stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
        
        if([timestampAndDisplayID count] != 2) {
            NSLog(@"-- unexpected path: %@", timestampAndDisplayID);
            continue;
        }
        
        NSString *timestamp = timestampAndDisplayID[0];
        NSString *displayID = timestampAndDisplayID[1];
        
        NSString *day = [timestamp substringToIndex:8];
        
        NSString *filename = [NSString stringWithFormat:@"%@_%@.mov", day, displayID];
        
        NSString *outPath = [_dirPath stringByAppendingPathComponent:filename];
        
        NSLog(@"-- merging into %@: %@", outPath, hourMovies);
        
        [SRTMovieMaker mergeMovieAtPaths:hourMovies intoPath:outPath completionHandler:^(NSString *path) {
            BOOL couldRemoveHourMovies = removeFiles(hourMovies);
            NSLog(@"-- could remove hour movies: %d", couldRemoveHourMovies);
        }];
    }
}

// screenshots -> hour movies
- (void)consolidateScreenshotsIntoHourMovies {
    
    NSString *todayHour = [[[NSDate date] srt_timestamp] substringToIndex:10];
    
    NSArray *filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_dirPath
                                                                             error:NULL];
    
    NSArray *hourImagesArrays = [[self class] filterFilenames:filenames
                                                directoryPath:_dirPath
                                                      withExt:@"jpg"
                                              timestampLength:14
                                                 beforeString:todayHour
                                      groupedByPrefixOfLength:10];
    
    
    if([hourImagesArrays count] == 0) {
        return;
    }
    
    for(NSArray *hourImages in hourImagesArrays) {
        
        NSArray *timestampAndDisplayID = [[[[hourImages firstObject] lastPathComponent] stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
        NSString *timestamp = timestampAndDisplayID[0];
        NSString *displayID = timestampAndDisplayID[1];
        
        if([timestampAndDisplayID count] != 2) {
            NSLog(@"-- unexpected path: %@", timestampAndDisplayID);
            continue;
        }
        
        NSString *filename = [timestamp substringToIndex:10];
        
        NSUInteger fps = [[NSUserDefaults standardUserDefaults] integerForKey:@"FramesPerSecond"];
        
        writeMovieFromJpgPaths(_dirPath, hourImages, filename, displayID, fps, ^(NSString *path) {
            
            assert([NSThread isMainThread]);
            
            NSLog(@"-- wrote %@", path);
            BOOL couldRemoveScreenshots = removeFiles(hourImages);
            NSLog(@"-- could remove screenshots: %d", couldRemoveScreenshots);
        });
    }
}

@end
