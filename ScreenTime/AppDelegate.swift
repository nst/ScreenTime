//
//  AppDelegate.swift
//  ScreenTime
//
//  Created by nst on 09/01/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Cocoa
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    @IBOutlet weak var window: NSWindow!
    
    @IBOutlet weak var menu : NSMenu!
    @IBOutlet weak var versionMenuItem : NSMenuItem!
    @IBOutlet weak var skipScreensaverMenuItem : NSMenuItem!
    @IBOutlet weak var startAtLoginMenuItem : NSMenuItem!
    @IBOutlet weak var pauseCaptureMenuItem : NSMenuItem!
    @IBOutlet weak var historyDepthMenuItem : NSMenuItem!
    @IBOutlet weak var historyContentsMenuItem : NSMenuItem!
    @IBOutlet weak var historyDepthView : NSView!
    @IBOutlet weak var historyDepthSlider : NSSlider!
    @IBOutlet weak var historyDepthTextField : NSTextField!
    
    var dirPath : String
    var statusItem : NSStatusItem
    var timer: Timer
    var screenShooter : ScreenShooter
    
    static var historyDays = [1,7,30,90,360, 0] // zero for never
    
    override init() {
        self.dirPath = ("~/Library/ScreenTime" as NSString).expandingTildeInPath
        
        //
        
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        //
        
        self.timer = Timer() // this instance won't be used
        
        self.screenShooter = ScreenShooter(path:dirPath)!
        
        super.init()
        
        let dirExists = self.ensureThatDirectoryExistsByCreatingOneIfNeeded(self.dirPath)
        
        guard dirExists else {
            print("-- cannot create \(self.dirPath)")
            
            let alert = NSAlert()
            alert.messageText = "ScreenTime cannot run"
            alert.informativeText = "Please create the ~/Library/ScreenTime/ directory";
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .critical
            
            let modalResponse = alert.runModal()
            
            if modalResponse == .alertFirstButtonReturn {
                NSApplication.shared.terminate(self)
                return
            }
            return
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        let defaults = ["SecondsBetweenScreenshots":60, "FramesPerSecond":2]
        UserDefaults.standard.register(defaults: defaults)
        
        /**/
        
        let currentVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")!
        
        let imageName = NSImage.Name(rawValue: "ScreenTime")
        let iconImage = NSImage(named: imageName)
        iconImage?.isTemplate = true
        
        self.statusItem.image = iconImage
        self.statusItem.highlightMode = true
        self.statusItem.toolTip = "ScreenTime \(currentVersionString)"
        self.statusItem.menu = self.menu;
        
        self.versionMenuItem.title = "Version \(currentVersionString)"
        
        self.historyDepthSlider.target = self
        self.historyDepthSlider.action = #selector(AppDelegate.historySliderDidMove(_:))
        
        self.historyDepthSlider.allowsTickMarkValuesOnly = true
        self.historyDepthSlider.maxValue = Double(type(of: self).historyDays.count - 1)
        self.historyDepthSlider.numberOfTickMarks = type(of: self).historyDays.count
        
        self.updateHistoryDepthLabelDescription()
        self.updateHistoryDepthSliderPosition()
        
        self.historyDepthMenuItem.view = self.historyDepthView
        
        self.menu.delegate = self
        
        /**/
        
        self.startTimer()
        
        /**/
        
        self.updateStartAtLaunchMenuItemState()
        self.updateSkipScreensaverMenuItemState()
        self.updatePauseCaptureMenuItemState()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        
        self.stopTimer()
    }
    
    func ensureThatDirectoryExistsByCreatingOneIfNeeded(_ path : String) -> Bool {
        
        let fm = FileManager.default
        var isDir : ObjCBool = false
        let fileExists = fm.fileExists(atPath: path, isDirectory:&isDir)
        if fileExists {
            return isDir.boolValue
        }
        
        // create file
        
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            print("-- created", path);
            return true
        } catch {
            print("-- error, cannot create \(path)", error)
            return false
        }
    }
    
    func startTimer() {
        print("-- startTimer")
        
        let optionalScreenShooter = ScreenShooter(path:dirPath)
        
        guard let existingScreenShooter = optionalScreenShooter else {
            
            let alert = NSAlert()
            alert.messageText = "ScreenTime cannot run"
            alert.informativeText = "Cannot use ~/Library/ScreenTime/ for screenshots";
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .critical
            
            let modalResponse = alert.runModal()
            
            if modalResponse == .alertFirstButtonReturn {
                NSApplication.shared.terminate(self)
            }
            
            return
        }
        
        self.screenShooter = existingScreenShooter
        screenShooter.makeScreenshotsAndConsolidate(nil)
        
        let timeInterval = UserDefaults.standard.integer(forKey: "SecondsBetweenScreenshots")
        
        self.timer.invalidate()
        self.timer = Timer.scheduledTimer(
            timeInterval: TimeInterval(timeInterval),
            target: screenShooter,
            selector: #selector(ScreenShooter.makeScreenshotsAndConsolidate(_:)),
            userInfo: nil,
            repeats: true)
        timer.tolerance = 10
        
        self.checkForUpdates()
    }
    
    func stopTimer() {
        print("-- stopTimer")
        
        timer.invalidate()
    }
    
    func updateStartAtLaunchMenuItemState() {
        let startAtLogin = LaunchServicesHelper().applicationIsInStartUpItems
        startAtLoginMenuItem.state = startAtLogin ? .on : .off;
    }
    
    func updateSkipScreensaverMenuItemState() {
        let skipScreensaver = UserDefaults.standard.bool(forKey: "SkipScreensaver")
        skipScreensaverMenuItem.state = skipScreensaver ? .on : .off
    }
    
    func updatePauseCaptureMenuItemState() {
        let captureIsPaused = self.timer.isValid == false
        pauseCaptureMenuItem.state = captureIsPaused ? .on : .off
    }
    
    @IBAction func about(_ sender:NSControl) {
        if let url = URL(string:"http://seriot.ch/screentime/") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @IBAction func openFolder(_ sender:NSControl) {
        NSWorkspace.shared.openFile(dirPath)
    }
    
    @IBAction func toggleSkipScreensaver(_ sender:NSControl) {
        let skipScreensaver = UserDefaults.standard.bool(forKey: "SkipScreensaver")
        
        UserDefaults.standard.set(!skipScreensaver, forKey: "SkipScreensaver");
        
        UserDefaults.standard.synchronize()
        
        self.updateSkipScreensaverMenuItemState()
    }
    
    @IBAction func toggleStartAtLogin(_ sender:NSControl) {
        LaunchServicesHelper().toggleLaunchAtStartup()
        
        self.updateStartAtLaunchMenuItemState()
    }
    
    @IBAction func togglePause(_ sender:NSControl) {
        let captureWasPaused = self.timer.isValid == false
        
        if captureWasPaused {
            self.startTimer()
        } else {
            self.stopTimer()
        }
        
        let imageName = NSImage.Name(rawValue: captureWasPaused ? "ScreenTime" : "ScreenTimePaused")
        if let iconImage = NSImage(named: imageName) {
            iconImage.isTemplate = true
            self.statusItem.image = iconImage
        } else {
            print("-- Error: cannot get image named \(imageName)")
        }
        
        self.updatePauseCaptureMenuItemState()
    }
    
    @IBAction func quit(_ sender:NSControl) {
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func historySliderDidMove(_ slider:NSSlider) {
        
        let sliderValue = slider.integerValue
        print("-- \(sliderValue)")
        
        let s = AppDelegate.historyPeriodDescriptionForSliderValue(sliderValue)
        
        self.historyDepthTextField.stringValue = s
        
        let numberOfDays = AppDelegate.historyNumberOfDaysForSliderValue(sliderValue)
        
        UserDefaults.standard.set(numberOfDays, forKey: "HistoryToKeepInDays")
    }
    
    func checkForUpdates() {
        
        let url = URL(string:"http://www.seriot.ch/screentime/screentime.json")
        
        URLSession.shared.dataTask(with: url!, completionHandler: { (optionalData, response, error) -> Void in
            
            DispatchQueue.main.async(execute: {
                
                guard let data = optionalData,
                    let optionalDict = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as? [String:AnyObject],
                    let d = optionalDict,
                    let latestVersionString = d["latest_version_string"] as? String,
                    let latestVersionURL = d["latest_version_url"] as? String
                else {
                    return
                }
                
                print("-- latestVersionString: \(latestVersionString)")
                print("-- latestVersionURL: \(latestVersionURL)")
                
                let currentVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                
                let needsUpdate = currentVersionString < latestVersionString
                
                print("-- needsUpdate: \(needsUpdate)")
                if needsUpdate == false { return }
                
                let alert = NSAlert()
                alert.messageText = "ScreenTime \(latestVersionString) is Available"
                alert.informativeText = "Please download it and replace the current version.";
                alert.addButton(withTitle: "Download")
                alert.addButton(withTitle: "Cancel")
                alert.alertStyle = .critical
                
                let modalResponse = alert.runModal()
                
                if modalResponse == .alertFirstButtonReturn {
                    if let downloadURL = URL(string:latestVersionURL) {
                        NSWorkspace.shared.open(downloadURL)
                    }
                }
                
            })
            }) .resume()
    }
    
    class func sliderValueForNumberOfDays(_ numberOfDays:Int) -> Int {
        
        if let i = self.historyDays.index(of: numberOfDays) {
            return i
        }
        
        return 0
    }
    
    class func historyNumberOfDaysForSliderValue(_ value:Int) -> Int {
        
        if value >= self.historyDays.count {
            return 0
        }
        
        return self.historyDays[value]
    }
    
    class func historyPeriodDescriptionForSliderValue(_ value:Int) -> String {
        let i = self.historyNumberOfDaysForSliderValue(value)
        
        if i == 0 { return "Never" }
        if i == 1 { return "1 day" }
        
        return "\(i) days"
    }
    
    func updateHistoryDepthLabelDescription() {
        let numberOfDays = UserDefaults.standard.integer(forKey: "HistoryToKeepInDays")
        
        let sliderValue = AppDelegate.sliderValueForNumberOfDays(numberOfDays)
        
        let s = AppDelegate.historyPeriodDescriptionForSliderValue(sliderValue)
        
        historyDepthTextField.stringValue = s
    }
    
    func updateHistoryDepthSliderPosition() {
        let numberOfDays = UserDefaults.standard.integer(forKey: "HistoryToKeepInDays")
        historyDepthSlider.integerValue = AppDelegate.sliderValueForNumberOfDays(numberOfDays)
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu:NSMenu) {
        
        self.updateStartAtLaunchMenuItemState()
        
        guard let e = NSApp.currentEvent else { print("-- no event"); return }
        
        let modifierFlags = e.modifierFlags
            
        let optionKeyIsPressed = modifierFlags.contains(.option)
        let commandKeyIsPressed = modifierFlags.contains(.command)

        if(optionKeyIsPressed && commandKeyIsPressed) {
            screenShooter.makeScreenshotsAndConsolidate(nil)
        }
        self.versionMenuItem.isHidden = optionKeyIsPressed == false;
        
        // build history contents according to file system's contents
        
        guard let subMenu = self.historyContentsMenuItem.submenu else { return }
        subMenu.removeAllItems()
        
        let namesAndPaths = Consolidator.movies(dirPath)
        
        for (n,p) in namesAndPaths {
            let historyItem = subMenu.addItem(withTitle: n, action: #selector(AppDelegate.historyItemAction(_:)), keyEquivalent: "")
//            let historyItem = subMenu.addItem(withTitle: n, action: #selector(AppDelegate.historyItemAction(_:)), keyEquivalent: "")
            historyItem.representedObject = p
        }
    }
    
    @objc
    func historyItemAction(_ menuItem:NSMenuItem) {
        if let path = menuItem.representedObject as? String {
            print("-- open \(path)")
            NSWorkspace().openFile(path)
        }
    }
}
