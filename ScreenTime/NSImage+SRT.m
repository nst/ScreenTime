//
//  NSImage+SRT.m
//  ScreenTime
//
//  Created by Nicolas Seriot on 20/06/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

#import "NSImage+SRT.h"

@implementation NSImage (SRT)

- (BOOL)srt_writeAsJpegAtPath:(NSString *)path {
    NSData *imageData = [self TIFFRepresentation];
    NSBitmapImageRep *bitmapRep = [NSBitmapImageRep imageRepWithData:imageData];
    NSDictionary *properties = @{ NSImageCompressionFactor : @0.8 };
    NSData *jpegData = [bitmapRep representationUsingType:NSJPEGFileType properties:properties];
    
    NSError *error = nil;
    BOOL status = [jpegData writeToFile:path options:NSDataWritingAtomic error:&error];
    if(status == NO) {
        NSLog(@"-- can't write, error %@", [error localizedDescription]);
    }
    return status;
}

@end
