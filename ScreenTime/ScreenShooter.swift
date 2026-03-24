//
//  ScreenShooter.swift
//  ScreenTime
//
//  Created by nst on 10/01/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import AppKit
import ScreenCaptureKit

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

    func takeScreenshot(_ display: SCDisplay) async -> NSImage? {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.showsCursor = false

        do {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSImage(cgImage: image, size: NSZeroSize)
        } catch {
            print("-- screenshot error: \(error)")
            return nil
        }
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

        Task {
            guard CGPreflightScreenCaptureAccess() else {
                print("-- screen capture permission not granted, skipping screenshot")
                return
            }

            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                let displays = content.displays

                for display in displays {
                    if let image = await self.takeScreenshot(display) {
                        let displayIDForFilename = "\(display.displayID)"
                        _ = self.writeScreenshot(image, displayIDForFilename: displayIDForFilename)
                    }
                }
            } catch {
                print("-- can't get shareable content: \(error)")
            }

            let c = Consolidator(dirPath:self.directoryPath)

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

}
