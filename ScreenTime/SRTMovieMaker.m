//
//  SRTMovieMaker.m
//  ScreenTime
//
//  Created by Nicolas Seriot on 20/06/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

// inspired from

#import "SRTMovieMaker.h"

@import AppKit;
@import AVFoundation;

@interface SRTMovieMaker ()

@property (nonatomic) NSInteger height;
@property (nonatomic) NSInteger width;
@property (nonatomic) NSUInteger framesPerSecond;
@property (nonatomic) NSInteger frameCount;

@property (nonatomic, strong) AVAssetWriter *writer;
@property (nonatomic, strong) AVAssetWriterInput *input;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *adaptor;

@end

@implementation SRTMovieMaker

- (instancetype)initWithPath:(NSString *)path frameSize:(CGSize)size fps:(NSUInteger)fps {
    if (!(self = [super init])) return self;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        
        NSString *globallyUniqueString = [[NSProcessInfo processInfo] globallyUniqueString];
        NSString *newPath = [path stringByAppendingFormat:@"_%@", globallyUniqueString];
        NSError *error = nil;
        BOOL moveSuccess = [[NSFileManager defaultManager] moveItemAtPath:path toPath:newPath error:&error];
        if(moveSuccess == NO) {
            NSLog(@"-- %@ exists, cannot move it to %@", path, newPath);
            return nil;
        }
    }
    
    if (path == nil) {
        NSLog(@"-- error: path must be non-nil");
        return nil;
    }
    
    _height = lrint(size.height);
    _width = lrint(size.width);
    
    _framesPerSecond = fps;
    if (fps == 0) {
        NSLog(@"Error: Frames per second must be positive integer");
        return nil;
    }
    
    _frameCount = 0;
    
    NSError *error;
    
    // Create Movie URL
    NSURL *movieURL = [NSURL fileURLWithPath:path];
    if (!movieURL) {
        NSLog(@"Error creating URL from path (%@)", path);
        return nil;
    }
    
    // Create Asset Writer
    self.writer = [[AVAssetWriter alloc] initWithURL:movieURL fileType:AVFileTypeQuickTimeMovie error:&error];
    if (!_writer) {
        NSLog(@"Error creating asset writer: %@", error.localizedDescription);
        return nil;
    }
    
    // Create Input
    NSDictionary *videoSettings = @{AVVideoCodecKey : AVVideoCodecH264,
                                    AVVideoWidthKey : @(_width),
                                    AVVideoHeightKey : @(_height)};
    
    self.input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    
    
    if (!_input) {
        NSLog(@"Error creating asset writer input");
        return nil;
    }
    
    [_writer addInput:_input];
    
    // Build adapter
    self.adaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:_input sourcePixelBufferAttributes:nil];
    if (!_adaptor) {
        NSLog(@"Error creating pixel adaptor");
        return nil;
    }
    
    [_writer startWriting];
    [_writer startSessionAtSourceTime:kCMTimeZero];
    
    return self;
}

- (CVPixelBufferRef)createPixelBuffer {
    
    // Create Pixel Buffer
    NSDictionary *pixelBufferOptions = @{(NSString *) kCVPixelBufferCGImageCompatibilityKey : @YES,
                                         (NSString *) kCVPixelBufferCGBitmapContextCompatibilityKey : @YES};
    
    CVPixelBufferRef bufferRef = NULL;
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          _width,
                                          _height,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef) pixelBufferOptions,
                                          &bufferRef);
    if (status != kCVReturnSuccess) {
        NSLog(@"-- error creating pixel buffer");
        return NULL;
    }
    
    return bufferRef;
}

- (CVPixelBufferRef)createPixelBufferFromDrawingInBlock:(ContextDrawingBlock) block {
    if (!block) {
        NSLog(@"-- error: missing contect drawing block");
        return NULL;
    }
    
    CVPixelBufferRef pixelBufferRef = [self createPixelBuffer];
    if (!pixelBufferRef) return NULL;
    
    CVPixelBufferLockBaseAddress(pixelBufferRef, 0);
    void *pixelData = CVPixelBufferGetBaseAddress(pixelBufferRef);
    if (pixelData == NULL) {
        NSLog(@"-- error retrieving pixel buffer base address");
        CVPixelBufferUnlockBaseAddress(pixelBufferRef, 0);
        return NO;
    }
    
    CGColorSpaceRef RGBColorSpace = CGColorSpaceCreateDeviceRGB();
    if (RGBColorSpace == NULL) {
        NSLog(@"-- error creating RGB colorspace");
        return NO;
    }
    
    CGContextRef context = CGBitmapContextCreate(pixelData,
                                                 _width,
                                                 _height,
                                                 8,
                                                 4 * _width,
                                                 RGBColorSpace,
                                                 (CGBitmapInfo) kCGImageAlphaNoneSkipFirst);
    
    if (!context) {
        CGColorSpaceRelease(RGBColorSpace);
        CVPixelBufferUnlockBaseAddress(pixelBufferRef, 0);
        NSLog(@"-- error creating bitmap context");
        return NO;
    }
    
    // Perform drawing
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:NO];
    [NSGraphicsContext setCurrentContext:gc];
    block(context);
    [NSGraphicsContext restoreGraphicsState];
    
    CGColorSpaceRelease(RGBColorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pixelBufferRef, 0);
    
    return pixelBufferRef;
}

- (BOOL)appendImageFromDrawing:(ContextDrawingBlock)drawingBlock {
    if (!drawingBlock) return NO;
    
    CVPixelBufferRef pixelBufferRef = [self createPixelBufferFromDrawingInBlock:drawingBlock];
    if (!pixelBufferRef) return NO;
    
    while (!_input.isReadyForMoreMediaData);
    
    BOOL success = [_adaptor appendPixelBuffer:pixelBufferRef
                          withPresentationTime:CMTimeMake(_frameCount, (int32_t)_framesPerSecond)];
    
    if (!success) {
        NSLog(@"-- error writing frame %@", @(_frameCount));
        return NO;
    }
    
    _frameCount++;
    
    CVPixelBufferRelease(pixelBufferRef);
    return success;
}

- (BOOL)appendImage:(NSImage *)image {
    if (!image) return NO;
    
    __weak typeof(self) weakSelf = self;
    
    return [self appendImageFromDrawing:^(CGContextRef context) {
        CGRect rect = CGRectMake(0, 0, weakSelf.width, weakSelf.height);
        [[NSColor blackColor] set];
        NSRectFill(rect);
        [image drawInRect:rect];
    }];
}

- (void)endWritingMovieWithWithCompletionHandler:(void(^)(NSString *path))completionHandler {
    //    frameCount++;
    [_input markAsFinished];
    //    [_writer endSessionAtSourceTime:CMTimeMake(frameCount, (int32_t) framesPerSecond)];
    [_writer finishWritingWithCompletionHandler:^{
        NSString *path = _writer.outputURL.path;
        NSLog(@"-- wrote %@", path);
        self.writer = nil;
        self.input = nil;
        self.adaptor = nil;
        completionHandler(path);
    }];
}

+ (void)mergeMovieAtPaths:(NSArray *)inPaths intoPath:(NSString *)outPath completionHandler:(void(^)(NSString *path))completionHandler {
    
    AVMutableComposition *composition = [AVMutableComposition composition];
    
    
    AVMutableCompositionTrack *composedTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    
    CMTime time = kCMTimeZero;
    
    for(NSString *inPath in inPaths) {
        NSURL *fileURL = [NSURL fileURLWithPath:inPath];
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:fileURL options:nil];
        
        //        NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:asset];
        //        NSLog(@"-- compatiblePresets: %@", compatiblePresets);
        
        NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
        AVAssetTrack *firstTrack = [videoTracks firstObject];
        
        NSError *error = nil;
        BOOL success = [composedTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                                              ofTrack:firstTrack
                                               atTime:time
                                                error:&error];
        if(success == NO) {
            NSLog(@"-- cannot add %@, error %@", inPath, [error localizedDescription]);
        }
        
        time = CMTimeAdd(time, asset.duration);
    }
    
    /**/
    
    if([[NSFileManager defaultManager] fileExistsAtPath:outPath]) {
        NSError *error = nil;
        BOOL removeSuccess = [[NSFileManager defaultManager] removeItemAtPath:outPath error:&error];
        if(removeSuccess == NO) {
            NSLog(@"-- cannot remove %@, error %@", outPath, [error localizedDescription]);
            return;
        }
    }
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetAppleProRes422LPCM];
    exporter.outputURL = [[NSURL alloc] initFileURLWithPath:outPath];
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        
        /*
         AVAssetExportSessionStatusUnknown,
         AVAssetExportSessionStatusWaiting,
         AVAssetExportSessionStatusExporting,
         AVAssetExportSessionStatusCompleted,
         AVAssetExportSessionStatusFailed,
         AVAssetExportSessionStatusCancelled
         */
        
        if([exporter status] == AVAssetExportSessionStatusCompleted) {
            completionHandler(outPath);
        }
        
    }];
}

@end
