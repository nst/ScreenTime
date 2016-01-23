//
//  MovieMaker.swift
//  ScreenTime
//
//  Created by nst on 08/01/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

// inspired by Erica Sadun's MovieMaker class
// https://github.com/erica/useful-things/tree/master/useful%20pack/Movie%20Maker

import AVFoundation

public class MovieMaker {
        
    private var height : Int
    private var width : Int
    private var framesPerSecond : UInt?
    private var frameCount : UInt?
    
    private var writer : AVAssetWriter!
    private var input : AVAssetWriterInput?
    private var adaptor : AVAssetWriterInputPixelBufferAdaptor?
    
    public init?(path:String, frameSize:CGSize, fps:UInt) {
        
        self.height = Int(frameSize.height)
        self.width = Int(frameSize.width)

        guard fps > 0 else {
            print("-- error: frames per second must be a positive integer")
            return
        }
        
        let dm = NSFileManager.defaultManager()
        
        if dm.fileExistsAtPath(path) {
            let globallyUniqueString = NSProcessInfo.processInfo().globallyUniqueString
            let newPath = path + "_\(globallyUniqueString)"
            
            do {
                try dm.moveItemAtPath(path, toPath: newPath)
            } catch {
                print("-- cannot move \(path) to \(newPath)")
                return nil
            }
        }
        
        self.framesPerSecond = fps
        
        self.frameCount = 0;
        
        // Create Movie URL
        let movieURL = NSURL(fileURLWithPath: path)
        
        // Create Asset Writer
        do {
            self.writer = try AVAssetWriter(URL: movieURL, fileType: AVFileTypeQuickTimeMovie)
        } catch {
            print("-- error: cannot create asset writer, \(error)")
            return nil
        }
        
        // Create Input
        var videoSettings = [String:AnyObject]()
        videoSettings[AVVideoCodecKey] = AVVideoCodecH264
        videoSettings[AVVideoWidthKey] = width
        videoSettings[AVVideoHeightKey] = height
        
        self.input = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
        
        self.writer.addInput(input!)
        
        // Build adapter
        self.adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input!, sourcePixelBufferAttributes: nil)
        
        guard writer.startWriting() else {
            print("-- cannot start writing")
            return nil
        }
        
        writer.startSessionAtSourceTime(kCMTimeZero)
    }
    
    @objc(mergeMovieAtPaths:intoPath:completionHandler:error:)
    public class func mergeMovies(inPath:[String], outPath:String, completionHandler:((path:String) -> ())) throws {
        
        let composition = AVMutableComposition()
        
        let composedTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var time = kCMTimeZero
        
        try inPath.forEach { (inPath) -> () in
            let fileURL = NSURL(fileURLWithPath: inPath)
            let asset = AVURLAsset(URL: fileURL)
            let videoTracks = asset.tracksWithMediaType(AVMediaTypeVideo)
            let firstTrack = videoTracks.first
            
            guard let existingFirstTrack = firstTrack else { return }
            
            let timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration)
            
            try composedTrack.insertTimeRange(timeRange, ofTrack: existingFirstTrack, atTime: time)
            
            try composedTrack.insertTimeRange(
                CMTimeRangeMake(kCMTimeZero, asset.duration),
                ofTrack: existingFirstTrack,
                atTime: time)
            
            time = CMTimeAdd(time, asset.duration);
        }
        
        /**/
        
        let fm = NSFileManager.defaultManager()
        
        if fm.fileExistsAtPath(outPath) {
            try fm.removeItemAtPath(outPath)
        }
        
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleProRes422LPCM) else { return }
        
        exporter.outputURL = NSURL(fileURLWithPath: outPath)
        exporter.outputFileType = AVFileTypeQuickTimeMovie
        exporter.shouldOptimizeForNetworkUse = true
        
        exporter.exportAsynchronouslyWithCompletionHandler({ () -> Void in
            /*
            AVAssetExportSessionStatusUnknown,
            AVAssetExportSessionStatusWaiting,
            AVAssetExportSessionStatusExporting,
            AVAssetExportSessionStatusCompleted,
            AVAssetExportSessionStatusFailed,
            AVAssetExportSessionStatusCancelled
            */
            
            switch(exporter.status) {
            case .Completed:
                completionHandler(path:outPath)
            default:
                print(exporter.status)
            }
        })
    }
    
    public func appendImage(image:NSImage) -> Bool {
        
        return self.appendImageFromDrawing({ [unowned self] (context) -> () in
            let rect = CGRectMake(0, 0, CGFloat(self.width), CGFloat(self.height))
            NSColor.blackColor().set()
            NSRectFill(rect)
            image.drawInRect(rect)
            })
    }
    
    public func appendImageFromDrawing(@noescape drawingBlock:(context:CGContextRef) -> ()) -> Bool {
        
        guard let pixelBufferRef = self.createPixelBufferFromDrawing(drawingBlock) else {
            return false
        }
        
        guard let existingInput = input else {
            return false
        }
        
        while(existingInput.readyForMoreMediaData == false) {}
        
        guard let existingFrameCount = self.frameCount else { return false }
        guard let existimeFramesPerSecond = self.framesPerSecond else { return false }
        
        guard let existingAdaptor = self.adaptor else { return false }
        
        let cmTime = CMTimeMake(Int64(existingFrameCount), Int32(existimeFramesPerSecond))
        let success = existingAdaptor.appendPixelBuffer(pixelBufferRef, withPresentationTime: cmTime)
        
        if success == false {
            print("-- error writing frame \(self.frameCount!)")
            return false
        }
        
        self.frameCount! += 1
        
        return success
    }
    
    public func endWritingMovieWithWithCompletionHandler(completionHandler:(path:String) -> ()) {
        //    frameCount++;
        
        guard let existingInput = self.input else { return }
        
        existingInput.markAsFinished()
        
        //    [_writer endSessionAtSourceTime:CMTimeMake(frameCount, (int32_t) framesPerSecond)];
        
        self.writer.finishWritingWithCompletionHandler { () -> Void in
            guard let path = self.writer.outputURL.path else { return }
            print("-- wrote", path)
            self.input = nil
            self.adaptor = nil
            completionHandler(path:path)
        }
    }
    
    private func createPixelBuffer() -> CVPixelBufferRef? {
        
        // Create Pixel Buffer
        let pixelBufferOptions : NSDictionary = [kCVPixelBufferCGImageCompatibilityKey as NSString:true, kCVPixelBufferCGBitmapContextCompatibilityKey as NSString:true];
        
        var pixelBuffer : CVPixelBuffer? = nil;
        
        let status : CVReturn = CVPixelBufferCreate(kCFAllocatorDefault,
            self.width,
            self.height,
            kCVPixelFormatType_32ARGB,
            pixelBufferOptions as NSDictionary,
            &pixelBuffer)
        
        if (status != kCVReturnSuccess) {
            print("-- error creating pixel buffer")
            return nil
        }
        
        return pixelBuffer
    }
    
    private func createPixelBufferFromDrawing(@noescape contextDrawingBlock:(context:CGContextRef) -> ()) -> CVPixelBufferRef? {
        
        guard let pixelBufferRef = self.createPixelBuffer() else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBufferRef, 0)
        let pixelData = CVPixelBufferGetBaseAddress(pixelBufferRef)
        let RGBColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGBitmapContextCreate(
            pixelData,
            self.width,
            self.height,
            8,
            4 * self.width,
            RGBColorSpace,
            CGImageAlphaInfo.NoneSkipFirst.rawValue) else {
                print("-- error creating bitmap context")
                CVPixelBufferUnlockBaseAddress(pixelBufferRef, 0)
                return nil
        }
        
        // Perform drawing
        NSGraphicsContext.saveGraphicsState()
        let gc = NSGraphicsContext(CGContext: context, flipped: false)
        
        NSGraphicsContext.setCurrentContext(gc)
        
        contextDrawingBlock(context: context)
        
        NSGraphicsContext.restoreGraphicsState()
        
        CVPixelBufferUnlockBaseAddress(pixelBufferRef, 0);
        
        return pixelBufferRef;
    }
}
