//
//  NSImage+SRT.h
//  ScreenTime
//
//  Created by Nicolas Seriot on 20/06/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (SRT)

- (BOOL)writeAsJpegAtPath:(NSString*)path;

@end
