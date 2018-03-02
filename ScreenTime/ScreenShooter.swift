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
        
        let fm = FileManager.default
        
        var isDir : ObjCBool = false
        let fileExists = fm.fileExists(atPath: path, isDirectory: &isDir)
        if fileExists == false || isDir.boolValue == false {
            do {
                try fm.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                print("-- created", path);
            } catch {
                print("-- error, cannot create", path, error)
                directoryPath = ""
                return nil
            }
        }
        
        self.directoryPath = path;
    }
    
    func takeScreenshot(_ displayID:CGDirectDisplayID) -> NSImage? {
        guard let imageRef = CGDisplayCreateImage(displayID) else { return nil }
        return NSImage(cgImage: imageRef, size: NSZeroSize)
    }
    
    func writeScreenshot(_ image:NSImage, displayIDForFilename:String) -> Bool {
        
        let timestamp = Date().srt_timestamp()
        let filename = timestamp + "_\(displayIDForFilename).jpg"
        
        let path = (directoryPath as NSString).appendingPathComponent(filename)
        
        let success = image.srt_writeAsJpeg(path)
        
        if(success) {
            print("-- write", path)
        } else {
            print("-- can't write", path)
        }
        
        return success
    }
    
    func isRunningScreensaver() -> Bool {
        let runningApplications = NSWorkspace.shared.runningApplications
        
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
    func makeScreenshotsAndConsolidate(_ timer:Timer?) {
        if UserDefaults.standard.bool(forKey: "SkipScreensaver") && self.isRunningScreensaver() {
            return
        }
        
        if UserDefaults.standard.bool(forKey: "PauseCapture") {
            print("-- capture pause prevented screenshot");
            return
        }
        
        let MAX_DISPLAYS : UInt32 = 16
        
        var displayCount: UInt32 = 0;
        let result = CGGetActiveDisplayList(0, nil, &displayCount)
        if result != .success {
            print("-- can't get active display list, error: \(result)")
            return
        }
        
        let allocated = Int(displayCount)
        let activeDisplays = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: allocated)
        
        let status : CGError = CGGetActiveDisplayList(MAX_DISPLAYS, activeDisplays, &displayCount)
        if status != .success {
            print("-- cannot get active display list, error \(status)")
        }
        
        for i in 0..<displayCount {
            let displayID = activeDisplays[Int(i)]
            let image = self.takeScreenshot(displayID)
            if let existingImage = image {
                let displayIDForFilename = "\(displayID)"
                _ = self.writeScreenshot(existingImage, displayIDForFilename:displayIDForFilename)
            }
        }
        
        let c = Consolidator(dirPath:directoryPath)
        
        do {
            try c.consolidateHourMoviesIntoDayMovies()
            
            try c.consolidateScreenshotsIntoHourMovies()
            
            let maxAgeInDays = UserDefaults.standard.integer(forKey: "HistoryToKeepInDays")
            
            try c.removeFilesOlderThanNumberOfDays(maxAgeInDays)
        } catch {
            print("-- cannot consolidate, error \(error)")
        }
    }
    
}
