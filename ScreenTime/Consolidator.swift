//
//  Consolidator.swift
//  ScreenTime
//
//  Created by nst on 10/01/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import AppKit

class Consolidator {
    
    var dirPath : String
    
    class func removeFiles(paths:[String]) {
        for path in paths {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(path)
            } catch {
                print("-- could not remove \(path), error \(error)")
            }
        }
    }
    
    class func timestampInFilename(filename:String) -> String {
        let timestampAndDisplayID = ((filename as NSString).lastPathComponent as NSString).stringByDeletingPathExtension.componentsSeparatedByString("_")
        return timestampAndDisplayID[0]
    }
    
    class func writeMovieFromJpgPaths(dirPath:String, jpgPaths:[String], movieName:String, displayIDString:NSString, fps:Int, completionHandler:(String) -> ()) {
        
        guard jpgPaths.isEmpty == false else {
            print("-- no screenshots to turn into movie")
            return
        }
        
        guard fps > 0 else {
            print("-- fps must be > 0")
            return
        }
        
        // write movie
        
        let filename = "\(movieName)_\(displayIDString).mov"
        let moviePath = (dirPath as NSString).stringByAppendingPathComponent(filename)
        
        let fm = NSFileManager.defaultManager()
        let fileExists = fm.fileExistsAtPath(moviePath)
        if fileExists {
            do {
                try fm.removeItemAtPath(moviePath)
            } catch {
                print("-- can't remove \(moviePath), error: \(error)")
            }
        }
        
        let firstImage = NSImage(contentsOfFile: jpgPaths.first!)
        guard let existingFirstImage = firstImage else {
            print("-- cannot get first image at \(jpgPaths.first!)")
            return
        }
        
        let movieMaker = MovieMaker(path: moviePath, frameSize: existingFirstImage.size, fps: UInt(fps))
        
        guard movieMaker != nil else { return }
        
        for jpgPath in jpgPaths {
            
            guard let image = NSImage(contentsOfFile:jpgPath) else {
                continue
            }
            
            let timestamp = timestampInFilename(jpgPath)
            
            let formattedDate = NSDate.srt_prettyDateFromTimestamp(timestamp)
            
            movieMaker!.appendImageFromDrawing({ (context) -> () in
                
                // draw image
                let rect = CGRectMake(0, 0, image.size.width, image.size.height)
                image.drawInRect(rect)
                
                // draw string frame
                let STRING_RECT_ORIGIN_X : CGFloat = rect.size.width - 320
                let STRING_RECT_ORIGIN_Y : CGFloat = 32
                let STRING_RECT_WIDTH : CGFloat = 300
                let STRING_RECT_HEIGHT : CGFloat = 54
                let stringRect : CGRect = CGRectMake(STRING_RECT_ORIGIN_X, STRING_RECT_ORIGIN_Y, STRING_RECT_WIDTH, STRING_RECT_HEIGHT);
                
                NSColor.whiteColor().setFill()
                NSColor.blackColor().setStroke()
                NSRectFill(stringRect)
                NSBezierPath.strokeRect(stringRect)
                
                // draw string
                let font = NSFont(name:"Courier", size:24)!
                let attributes : [String:AnyObject] = [NSFontAttributeName:font, NSForegroundColorAttributeName:NSColor.blueColor()]
                
                let s = NSAttributedString(string: (formattedDate as NSString).lastPathComponent, attributes: attributes)
                s.drawAtPoint(CGPointMake(STRING_RECT_ORIGIN_X + 16, STRING_RECT_ORIGIN_Y + 16))
            })
        }
        
        movieMaker!.endWritingMovieWithWithCompletionHandler({ (path) -> () in
            dispatch_async(dispatch_get_main_queue(), {
                completionHandler(path)
            })
        })
    }
    
    /*
    consolidate past assets
    
    for each past day
    ...make hour movie from day images
    ...make day movie from hour movies
    
    for each today past hour
    ...make hour movie
    */
    
    init(dirPath:String) {
        self.dirPath = dirPath
    }
    
    static let dateFormatter: NSDateFormatter = {
        let df = NSDateFormatter()
        df.dateFormat = "yyyyMMdd"
        return df
    }()
    
    class func filterFilename(
        paths:[String],
        dirPath:String,
        withExt:String,
        timestampLength:Int,
        beforeString:String,
        groupedByPrefixOfLength groupPrefixLength:Int) -> [[String]] {
            
            let filteredPaths = paths.filter {
                let p = ($0 as NSString)
                let ext = ($0 as NSString)
                if p.pathExtension.lowercaseString == ext.lowercaseString { return false }
                let filename = (p.lastPathComponent as NSString).stringByDeletingPathExtension
                let components = filename.componentsSeparatedByString("_")
                if components.count != 2 { return false }
                let timestamp = components[0]
                if timestamp.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) != timestampLength { return false }
                return beforeString.compare(filename) == .OrderedDescending
            }
            
            //
            
            var groupDictionary = [String:[String]]()
            
            for path in filteredPaths {
                
                let prefix = ((path as NSString).lastPathComponent as NSString).substringToIndex(groupPrefixLength) // timestamp
                let optSuffix = ((path as NSString).lastPathComponent as NSString).stringByDeletingPathExtension.componentsSeparatedByString("_").last
                
                guard let suffix = optSuffix else { continue }
                
                let key = "\(prefix)_\(suffix)"
                
                if groupDictionary[key] == nil { groupDictionary[key] = [String]() }
                
                let fullPath = (dirPath as NSString).stringByAppendingPathComponent(path)
                groupDictionary[key]?.append(fullPath)
            }
            
            let sortedKeys = groupDictionary.keys.sort()
            
            var groups = [[String]]()
            
            for key in sortedKeys {
                if let group = groupDictionary[key] {
                    groups.append( group )
                }
            }
            
            return groups
    }
    
    // hour movies -> day movies
    func consolidateHourMoviesIntoDayMovies() throws {
        
        let today = (NSDate().srt_timestamp() as NSString).substringToIndex(8)
        let filenames = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(dirPath)
        
        let hourMoviesArrays = Consolidator.filterFilename(
            filenames,
            dirPath: dirPath,
            withExt: "mov",
            timestampLength: 10,
            beforeString: today,
            groupedByPrefixOfLength: 8)
        
        for hourMovies in hourMoviesArrays {
            
            guard hourMovies.count > 0 else { continue }
            
            let timestampAndDisplayID = ((hourMovies.first! as NSString).lastPathComponent as NSString).stringByDeletingPathExtension.componentsSeparatedByString("_")
            
            if timestampAndDisplayID.count != 2 {
                print("-- unexpected path: \(timestampAndDisplayID)")
                continue
            }
            
            let timestamp = timestampAndDisplayID[0]
            let displayID = timestampAndDisplayID[1]
            
            let day = (timestamp as NSString).substringToIndex(8)
            
            let filename = "\(day)_\(displayID).mov"
            
            let outPath = (dirPath as NSString).stringByAppendingPathComponent(filename)
            
            print("-- merging into \(outPath): \(hourMovies)")
            
            do {
                try MovieMaker.mergeMovies(hourMovies, outPath: outPath, completionHandler: { (path) -> () in
                    Consolidator.removeFiles(hourMovies)
                })
            } catch {
                print("-- could not merge movies, \(error)")
            }
        }
    }
    
    // screenshots -> hour movies
    func consolidateScreenshotsIntoHourMovies() throws {
        
        let todayHour = (NSDate().srt_timestamp() as NSString).substringToIndex(10)
        let filenames = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(dirPath)
        
        let hourImagesArrays = Consolidator.filterFilename(
            filenames,
            dirPath: dirPath,
            withExt: "jpg",
            timestampLength: 14,
            beforeString: todayHour,
            groupedByPrefixOfLength: 10)
        
        for hourImages in hourImagesArrays {
            
            guard hourImages.count > 0 else { continue }

            let timestampAndDisplayID = ((hourImages.first! as NSString).lastPathComponent as NSString).stringByDeletingPathExtension.componentsSeparatedByString("_")
            
            if timestampAndDisplayID.count != 2 {
                print("-- unexpected path format: \(timestampAndDisplayID)")
                continue
            }
            
            let timestamp = timestampAndDisplayID[0]
            let displayID = timestampAndDisplayID[1]
            
            let filename = (timestamp as NSString).substringToIndex(10)
            
            let fps : Int = NSUserDefaults.standardUserDefaults().integerForKey("FramesPerSecond")
            
            Consolidator.writeMovieFromJpgPaths(
                dirPath,
                jpgPaths: hourImages,
                movieName: filename,
                displayIDString: displayID,
                fps: fps,
                completionHandler: { (path) -> () in
                    Consolidator.removeFiles(hourImages)
            })
        }
    }
    
    class func movies(dirPath:String) -> [(prettyName:String, path:String)] {
    
        let fm = NSFileManager.defaultManager()
        
        do {
            let contents = try fm.contentsOfDirectoryAtPath(dirPath)
            
            return contents
                .filter({ ($0 as NSString).pathExtension == "mov" })
                .map({ (prettyName:$0, path:"\(dirPath)/\($0)") })
        } catch {
            return []
        }
    }
    
    class func dateOfDayForFilename(filename:String) -> NSDate? {
        
        guard filename.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) >= 8 else {
            return nil
        }
        
        let s = (filename as NSString).substringToIndex(8)
        
        return self.dateFormatter.dateFromString(s)
    }
    
    class func daysBetweenDates(var date1:NSDate, var date2:NSDate) -> Int {
        if date1.compare(date2) == .OrderedDescending {
            (date1, date2) = (date2, date1)
        }
        
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(.Day, fromDate: date1, toDate: date2, options: [])
        return components.day
    }
    
    func removeFilesOlderThanNumberOfDays(historyToKeepInDays:Int) throws {
        
        guard historyToKeepInDays > 0 else { return }
        
        let fm = NSFileManager.defaultManager()
        
        let contents = try fm.contentsOfDirectoryAtPath(dirPath)
        
        let now = NSDate()
        
        for filename in contents {
            if let date = Consolidator.dateOfDayForFilename(filename) {
                let fileAgeInDays = Consolidator.daysBetweenDates(date, date2: now)
                
                if fileAgeInDays > historyToKeepInDays {
                    let path = (dirPath as NSString).stringByAppendingPathComponent(filename)
                    print("-- removing file with age in days: \(fileAgeInDays), \(path)")
                    
                    do {
                        try fm.removeItemAtPath(path)
                    } catch {
                        print("-- cannot remove \(path), \(error)")
                    }
                }
            }
            
        }
    }
}
