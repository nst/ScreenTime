//
//  SRTMovieMaker.h
//  ScreenTime
//
//  Created by Nicolas Seriot on 20/06/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

// heavily inspired from the MovieMaker class by Erica Sadun

#import <Foundation/Foundation.h>

typedef void (^ContextDrawingBlock)(CGContextRef context);

@interface SRTMovieMaker : NSObject

- (instancetype)initWithPath:(NSString *)path
                   frameSize:(CGSize)size
                         fps:(NSUInteger)fps;

- (BOOL)appendImage:(NSImage *)image;

- (BOOL)appendImageFromDrawing:(ContextDrawingBlock)drawingBlock;

- (void)endWritingMovieWithWithCompletionHandler:(void(^)(NSString *path))completionHandler;

+ (void)mergeMovieAtPaths:(NSArray *)inPaths intoPath:(NSString *)outPath completionHandler:(void(^)(NSString *path))completionHandler;

@end
