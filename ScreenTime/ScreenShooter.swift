//
//  ScreenShooter.swift
//  ScreenTime
//
//  Created by nst on 10/01/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import AppKit

class ScreenShooter {
    
    var directoryPath : String
    
    init?(path:String) {
        
        let fm = NSFileManager.defaultManager()
        
        var isDir : ObjCBool = false
        let fileExists = fm.fileExistsAtPath(path, isDirectory: &isDir)
        if fileExists == false || Bool(isDir) == false {
            do {
                try fm.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
                print("-- created", path);
            } catch {
                print("-- error, cannot create", path, error)
                directoryPath = ""
                return nil
            }
        }
        
        self.directoryPath = path;
    }
    
    func takeScreenshot(displayID:CGDirectDisplayID) -> NSImage? {
        guard let imageRef = CGDisplayCreateImage(displayID) else { return nil }
        return NSImage(CGImage: imageRef, size: NSZeroSize)
    }
    
    func writeScreenshot(image:NSImage, displayIDForFilename:String) -> Bool {
        
        let timestamp = NSDate().srt_timestamp()
        let filename = timestamp.stringByAppendingString("_\(displayIDForFilename).jpg")
        
        let path = (directoryPath as NSString).stringByAppendingPathComponent(filename)
        
        let success = image.srt_writeAsJpeg(path)
        
        if(success) {
            print("-- write", path)
        } else {
            print("-- can't write", path)
        }
        
        return success
    }
    
    func isRunningScreensaver() -> Bool {
        let runningApplications = NSWorkspace.sharedWorkspace().runningApplications
        
        for app in runningApplications {
            if let bundlerIdentifier = app.bundleIdentifier {
                if bundlerIdentifier.hasPrefix("com.apple.ScreenSaver") {
                    return true
                }
            }
        }
        return false
    }
    
    @objc
    func makeScreenshotsAndConsolidate(timer:NSTimer?) {
        if NSUserDefaults.standardUserDefaults().boolForKey("SkipScreensaver") && self.isRunningScreensaver() {
            return
        }
        
        if NSUserDefaults.standardUserDefaults().boolForKey("PauseCapture") {
            print("-- capture pause prevented screenshot");
            return
        }
        
        let MAX_DISPLAYS : UInt32 = 16
        
        var displayCount: UInt32 = 0;
        let result = CGGetActiveDisplayList(0, nil, &displayCount)
        if result != .Success {
            print("-- can't get active display list, error: \(result)")
            return
        }
        
        let allocated = Int(displayCount)
        let activeDisplays = UnsafeMutablePointer<CGDirectDisplayID>.alloc(allocated)
        
        let status : CGError = CGGetActiveDisplayList(MAX_DISPLAYS, activeDisplays, &displayCount)
        if status != .Success {
            print("-- cannot get active display list, error \(status)")
        }
        
        for i in 0..<displayCount {
            let displayID = activeDisplays[Int(i)]
            let image = self.takeScreenshot(displayID)
            if let existingImage = image {
                let displayIDForFilename = "\(displayID)"
                self.writeScreenshot(existingImage, displayIDForFilename:displayIDForFilename)
            }
        }
        
        let c = Consolidator(dirPath:directoryPath)
        
        do {
            try c.consolidateHourMoviesIntoDayMovies()
            
            try c.consolidateScreenshotsIntoHourMovies()
            
            let maxAgeInDays = NSUserDefaults.standardUserDefaults().integerForKey("HistoryToKeepInDays")
            
            try c.removeFilesOlderThanNumberOfDays(maxAgeInDays)
        } catch {
            print("-- cannot consolidate, error \(error)")
        }
    }
    
}