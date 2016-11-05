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
    
    class func removeFiles(_ paths:[String]) {
        for path in paths {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                print("-- could not remove \(path), error \(error)")
            }
        }
    }
    
    class func timestampInFilename(_ filename:String) -> String {
        let timestampAndDisplayID = ((filename as NSString).lastPathComponent as NSString).deletingPathExtension.components(separatedBy: "_")
        return timestampAndDisplayID[0]
    }
    
    class func writeMovieFromJpgPaths(_ dirPath:String, jpgPaths:[String], movieName:String, displayIDString:NSString, fps:Int, completionHandler:@escaping (String) -> ()) {
        
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
        let moviePath = (dirPath as NSString).appendingPathComponent(filename)
        
        let fm = FileManager.default
        let fileExists = fm.fileExists(atPath: moviePath)
        if fileExists {
            do {
                try fm.removeItem(atPath: moviePath)
            } catch {
                print("-- can't remove \(moviePath), error: \(error)")
            }
        }
        
        let firstImage = NSImage(contentsOfFile: jpgPaths.first!)
        guard let existingFirstImage = firstImage else {
            print("-- cannot get first image at \(jpgPaths.first!)")
            return
        }
        
        guard let movieMaker = MovieMaker(path: moviePath, frameSize: existingFirstImage.size, fps: UInt(fps)) else { return }
        
        for jpgPath in jpgPaths {
            
            guard let image = NSImage(contentsOfFile:jpgPath) else {
                continue
            }
            
            let timestamp = timestampInFilename(jpgPath)
            
            let formattedDate = Date.srt_prettyDateFromTimestamp(timestamp)
            
            _ = movieMaker.appendImageFromDrawing({ (context) -> () in
                
                // draw image
                let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
                image.draw(in: rect)
                
                // draw string frame
                let STRING_RECT_ORIGIN_X : CGFloat = rect.size.width - 320
                let STRING_RECT_ORIGIN_Y : CGFloat = 32
                let STRING_RECT_WIDTH : CGFloat = 300
                let STRING_RECT_HEIGHT : CGFloat = 54
                let stringRect : CGRect = CGRect(x: STRING_RECT_ORIGIN_X, y: STRING_RECT_ORIGIN_Y, width: STRING_RECT_WIDTH, height: STRING_RECT_HEIGHT);
                
                NSColor.white.setFill()
                NSColor.black.setStroke()
                NSRectFill(stringRect)
                NSBezierPath.stroke(stringRect)
                
                // draw string
                let font = NSFont(name:"Courier", size:24)!
                let attributes : [String:AnyObject] = [NSFontAttributeName:font, NSForegroundColorAttributeName:NSColor.blue]
                
                let s = NSAttributedString(string: (formattedDate as NSString).lastPathComponent, attributes: attributes)
                s.draw(at: CGPoint(x: STRING_RECT_ORIGIN_X + 16, y: STRING_RECT_ORIGIN_Y + 16))
            })
        }
        
        movieMaker.endWritingMovieWithWithCompletionHandler({ (path) -> () in
            DispatchQueue.main.async(execute: {
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
    
    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        return df
    }()
    
    class func filterFilename(
        _ paths:[String],
        dirPath:String,
        withExt ext:String,
        timestampLength:Int,
        beforeString:String,
        groupedByPrefixOfLength groupPrefixLength:Int) -> [[String]] {
            
            let filteredPaths = paths.filter {
                let p = ($0 as NSString)
                if p.pathExtension.lowercased() != ext.lowercased() { return false }
                let filename = (p.lastPathComponent as NSString).deletingPathExtension
                let components = filename.components(separatedBy: "_")
                if components.count != 2 { return false }
                let timestamp = components[0]
                if timestamp.lengthOfBytes(using: String.Encoding.utf8) != timestampLength { return false }
                return beforeString.compare(filename) == .orderedDescending
            }
            
            //
            
            var groupDictionary = [String:[String]]()
            
            for path in filteredPaths {
                
                let lastPathComponent = ((path as NSString).lastPathComponent as NSString)
                let prefix = lastPathComponent.substring(to: groupPrefixLength) // timestamp
                let components = lastPathComponent.deletingPathExtension.components(separatedBy: "_")
                guard components.count == 2 else {
                    print("-- unexpected lastPathComponent: \(lastPathComponent)")
                    continue
                }
                let suffix = components[1]
                
                let key = "\(prefix)_\(suffix)"
                
                if groupDictionary[key] == nil { groupDictionary[key] = [String]() }
                
                let fullPath = (dirPath as NSString).appendingPathComponent(path)
                groupDictionary[key]?.append(fullPath)
            }
            
            let sortedKeys = groupDictionary.keys.sorted()
            
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
        
        let today = (Date().srt_timestamp() as NSString).substring(to: 8)
        let filenames = try FileManager.default.contentsOfDirectory(atPath: dirPath)
        
        let hourMoviesArrays = Consolidator.filterFilename(
            filenames,
            dirPath: dirPath,
            withExt: "mov",
            timestampLength: 10,
            beforeString: today,
            groupedByPrefixOfLength: 8)
        
        for hourMovies in hourMoviesArrays {
            
            guard hourMovies.count > 0 else { continue }
            
            let timestampAndDisplayID = ((hourMovies.first! as NSString).lastPathComponent as NSString).deletingPathExtension.components(separatedBy: "_")
            
            guard timestampAndDisplayID.count == 2 else {
                print("-- unexpected path: \(timestampAndDisplayID)")
                continue
            }
            
            let timestamp = timestampAndDisplayID[0]
            let displayID = timestampAndDisplayID[1]
            
            let day = (timestamp as NSString).substring(to: 8)
            
            let filename = "\(day)_\(displayID).mov"
            
            let outPath = (dirPath as NSString).appendingPathComponent(filename)
            
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
        
        let todayHour = (Date().srt_timestamp() as NSString).substring(to: 10)
        let filenames = try FileManager.default.contentsOfDirectory(atPath: dirPath)
        
        let hourImagesArrays = Consolidator.filterFilename(
            filenames,
            dirPath: dirPath,
            withExt: "jpg",
            timestampLength: 14,
            beforeString: todayHour,
            groupedByPrefixOfLength: 10)
        
        for hourImages in hourImagesArrays {
            
            guard hourImages.count > 0 else { continue }

            let timestampAndDisplayID = ((hourImages.first! as NSString).lastPathComponent as NSString).deletingPathExtension.components(separatedBy: "_")
            
            if timestampAndDisplayID.count != 2 {
                print("-- unexpected path format: \(timestampAndDisplayID)")
                continue
            }
            
            let timestamp = timestampAndDisplayID[0]
            let displayID = timestampAndDisplayID[1]
            
            let filename = (timestamp as NSString).substring(to: 10)
            
            let fps : Int = UserDefaults.standard.integer(forKey: "FramesPerSecond")
            
            Consolidator.writeMovieFromJpgPaths(
                dirPath,
                jpgPaths: hourImages,
                movieName: filename,
                displayIDString: displayID as NSString,
                fps: fps,
                completionHandler: { (path) -> () in
                    Consolidator.removeFiles(hourImages)
            })
        }
    }
    
    class func movies(_ dirPath:String) -> [(prettyName:String, path:String)] {
    
        let fm = FileManager.default
        
        do {
            let contents = try fm.contentsOfDirectory(atPath: dirPath)
            
            return contents
                .filter({ ($0 as NSString).pathExtension == "mov" })
                .map({ (prettyName:$0, path:"\(dirPath)/\($0)") })
        } catch {
            return []
        }
    }
    
    class func dateOfDayForFilename(_ filename:String) -> Date? {
        
        guard filename.lengthOfBytes(using: String.Encoding.utf8) >= 8 else { return nil }
        
        let s = (filename as NSString).substring(to: 8)
        
        return self.dateFormatter.date(from: s)
    }
    
    class func daysBetweenDates(date1 d1:Date, date2 d2:Date) -> Int {
        
        var (date1, date2) = (d1, d2)
        
        if date1.compare(date2) == .orderedDescending {
            (date1, date2) = (date2, date1)
        }
        
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components(.day, from: date1, to: date2, options: [])
        return components.day!
    }
    
    func removeFilesOlderThanNumberOfDays(_ historyToKeepInDays:Int) throws {
        
        guard historyToKeepInDays > 0 else { return }
        
        let fm = FileManager.default
        
        let contents = try fm.contentsOfDirectory(atPath: dirPath)
        
        let now = Date()
        
        for filename in contents {
            
            guard let date = Consolidator.dateOfDayForFilename(filename) else { continue }
            
            let fileAgeInDays = Consolidator.daysBetweenDates(date1: date, date2: now)
            
            if fileAgeInDays > historyToKeepInDays {
                let path = (dirPath as NSString).appendingPathComponent(filename)
                print("-- removing file with age in days: \(fileAgeInDays), \(path)")
                
                do {
                    try fm.removeItem(atPath: path)
                } catch {
                    print("-- cannot remove \(path), \(error)")
                }
            }
            
        }
    }
}
