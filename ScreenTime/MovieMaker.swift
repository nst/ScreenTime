//
//  MovieMaker.swift
//  ScreenTime
//
//  Created by nst on 08/01/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

// inspired by Erica Sadun's MovieMaker class
// https://github.com/erica/useful-things/tree/master/useful%20pack/Movie%20Maker

import AppKit
import AVFoundation

open class MovieMaker {
        
    fileprivate var height : Int
    fileprivate var width : Int
    fileprivate var framesPerSecond : UInt?
    fileprivate var frameCount : UInt?
    
    fileprivate var writer : AVAssetWriter!
    fileprivate var input : AVAssetWriterInput?
    fileprivate var adaptor : AVAssetWriterInputPixelBufferAdaptor?
    
    public init?(path:String, frameSize:CGSize, fps:UInt) {
        
        self.height = Int(frameSize.height)
        self.width = Int(frameSize.width)

        guard fps > 0 else {
            print("-- error: frames per second must be a positive integer")
            return
        }
        
        let dm = FileManager.default
        
        if dm.fileExists(atPath: path) {
            let globallyUniqueString = ProcessInfo.processInfo.globallyUniqueString
            let newPath = path + "_\(globallyUniqueString)"
            
            do {
                try dm.moveItem(atPath: path, toPath: newPath)
            } catch {
                print("-- cannot move \(path) to \(newPath)")
                return nil
            }
        }
        
        self.framesPerSecond = fps
        
        self.frameCount = 0;
        
        // Create Movie URL
        let movieURL = URL(fileURLWithPath: path)
        
        // Create Asset Writer
        do {
            self.writer = try AVAssetWriter(outputURL: movieURL, fileType: AVFileTypeQuickTimeMovie)
        } catch {
            print("-- error: cannot create asset writer, \(error)")
            return nil
        }
        
        // Create Input
        var videoSettings = [String:AnyObject]()
        videoSettings[AVVideoCodecKey] = AVVideoCodecH264 as AnyObject?
        videoSettings[AVVideoWidthKey] = width as AnyObject?
        videoSettings[AVVideoHeightKey] = height as AnyObject?
        
        self.input = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
        
        self.writer.add(input!)
        
        // Build adapter
        self.adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input!, sourcePixelBufferAttributes: nil)
        
        guard writer.startWriting() else {
            print("-- cannot start writing")
            return nil
        }
        
        writer.startSession(atSourceTime: kCMTimeZero)
    }
    
    @objc(mergeMovieAtPaths:intoPath:completionHandler:error:)
    open class func mergeMovies(_ inPath:[String], outPath:String, completionHandler:@escaping ((_ path:String) -> ())) throws {
        
        let composition = AVMutableComposition()
        
        let composedTrack = composition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var time = kCMTimeZero
        
        try inPath.forEach { (inPath) -> () in
            let fileURL = URL(fileURLWithPath: inPath)
            let asset = AVURLAsset(url: fileURL)
            let videoTracks = asset.tracks(withMediaType: AVMediaTypeVideo)
            let firstTrack = videoTracks.first
            
            guard let existingFirstTrack = firstTrack else { return }
            
            let timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration)
            
            try composedTrack.insertTimeRange(timeRange, of: existingFirstTrack, at: time)
            
            try composedTrack.insertTimeRange(
                CMTimeRangeMake(kCMTimeZero, asset.duration),
                of: existingFirstTrack,
                at: time)
            
            time = CMTimeAdd(time, asset.duration);
        }
        
        /**/
        
        let fm = FileManager.default
        
        if fm.fileExists(atPath: outPath) {
            try fm.removeItem(atPath: outPath)
        }
        
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleProRes422LPCM) else { return }
        
        exporter.outputURL = URL(fileURLWithPath: outPath)
        exporter.outputFileType = AVFileTypeQuickTimeMovie
        exporter.shouldOptimizeForNetworkUse = true
        
        exporter.exportAsynchronously(completionHandler: { () -> Void in
            /*
            AVAssetExportSessionStatusUnknown,
            AVAssetExportSessionStatusWaiting,
            AVAssetExportSessionStatusExporting,
            AVAssetExportSessionStatusCompleted,
            AVAssetExportSessionStatusFailed,
            AVAssetExportSessionStatusCancelled
            */
            
            switch(exporter.status) {
            case .completed:
                completionHandler(outPath)
            default:
                print(exporter.status)
            }
        })
    }
    
    open func appendImage(_ image:NSImage) -> Bool {
        
        return self.appendImageFromDrawing({ [unowned self] (context) -> () in
            let rect = CGRect(x:0, y:0, width:CGFloat(self.width), height:CGFloat(self.height))
            NSColor.black.set()
            NSRectFill(rect)
            image.draw(in:rect)
            })
    }
    
    open func appendImageFromDrawing(_ drawingBlock: (_ context:CGContext) -> ()) -> Bool {
        
        guard let pixelBufferRef = self.createPixelBufferFromDrawing(drawingBlock) else {
            return false
        }
        
        guard let existingInput = input else {
            return false
        }
        
        while(existingInput.isReadyForMoreMediaData == false) {}
        
        guard let existingFrameCount = self.frameCount else { return false }
        guard let existimeFramesPerSecond = self.framesPerSecond else { return false }
        
        guard let existingAdaptor = self.adaptor else { return false }
        
        let cmTime = CMTimeMake(Int64(existingFrameCount), Int32(existimeFramesPerSecond))
        let success = existingAdaptor.append(pixelBufferRef, withPresentationTime: cmTime)
        
        if success == false {
            print("-- error writing frame \(self.frameCount!)")
            return false
        }
        
        self.frameCount! += 1
        
        return success
    }
    
    open func endWritingMovieWithWithCompletionHandler(_ completionHandler:@escaping (_ path:String) -> ()) {
        //    frameCount++;
        
        guard let existingInput = self.input else { return }
        
        existingInput.markAsFinished()
        
        //    [_writer endSessionAtSourceTime:CMTimeMake(frameCount, (int32_t) framesPerSecond)];
        
        self.writer.finishWriting { () -> Void in
            let path = self.writer.outputURL.path
            print("-- wrote", path)
            self.input = nil
            self.adaptor = nil
            completionHandler(path)
        }
    }
    
    fileprivate func createPixelBuffer() -> CVPixelBuffer? {
        
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
    
    fileprivate func createPixelBufferFromDrawing(_ contextDrawingBlock: (_ context:CGContext) -> ()) -> CVPixelBuffer? {
        
        guard let pixelBufferRef = self.createPixelBuffer() else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBufferRef, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBufferRef)
        let RGBColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: self.width,
            height: self.height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * self.width,
            space: RGBColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
                print("-- error creating bitmap context")
                CVPixelBufferUnlockBaseAddress(pixelBufferRef, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                return nil
        }
        
        // Perform drawing
        NSGraphicsContext.saveGraphicsState()
        let gc = NSGraphicsContext(cgContext: context, flipped: false)
        
        NSGraphicsContext.setCurrent(gc)
        
        contextDrawingBlock(context)
        
        NSGraphicsContext.restoreGraphicsState()
        
        CVPixelBufferUnlockBaseAddress(pixelBufferRef, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)));
        
        return pixelBufferRef;
    }
}
