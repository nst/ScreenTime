//
//  AppDelegate.swift
//  ScreenTime
//
//  Created by nst on 09/01/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Cocoa

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
    var timer: NSTimer
    var screenShooter : ScreenShooter
    
    static var historyDays = [1,7,30,90,360, 0] // zero for never
    
    override init() {
        self.dirPath = ("~/Library/ScreenTime" as NSString).stringByExpandingTildeInPath
        
        //
        
        self.statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
        
        //
        
        self.timer = NSTimer() // this instance won't be used
        
        self.screenShooter = ScreenShooter(path:dirPath)!
        
        super.init()
        
        let dirExists = self.ensureThatDirectoryExistsByCreatingOneIfNeeded(self.dirPath)
        
        guard dirExists else {
            print("-- cannot create \(self.dirPath)")
            
            let alert = NSAlert()
            alert.messageText = "ScreenTime cannot run"
            alert.informativeText = "Please create the ~/Library/ScreenTime/ directory";
            alert.addButtonWithTitle("OK")
            alert.alertStyle = .CriticalAlertStyle
            
            let modalResponse = alert.runModal()
            
            if modalResponse == NSAlertFirstButtonReturn {
                NSApplication.sharedApplication().terminate(self)
                return
            }
            return
        }
    }
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        
        let defaults = ["SecondsBetweenScreenshots":60, "FramesPerSecond":2]
        NSUserDefaults.standardUserDefaults().registerDefaults(defaults)
        
        /**/
        
        let currentVersionString = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString")!
        
        let iconImage = NSImage(named: "ScreenTime")
        iconImage?.template = true
        
        self.statusItem.image = iconImage
        self.statusItem.highlightMode = true
        self.statusItem.toolTip = "ScreenTime \(currentVersionString)"
        self.statusItem.menu = self.menu;
        
        self.versionMenuItem.title = "Version \(currentVersionString)"
        
        self.historyDepthSlider.target = self
        self.historyDepthSlider.action = "historySliderDidMove:"
        
        self.historyDepthSlider.allowsTickMarkValuesOnly = true
        self.historyDepthSlider.maxValue = Double(self.dynamicType.historyDays.count - 1)
        self.historyDepthSlider.numberOfTickMarks = self.dynamicType.historyDays.count
        
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
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        
        self.stopTimer()
    }
    
    func ensureThatDirectoryExistsByCreatingOneIfNeeded(path : String) -> Bool {
        
        let fm = NSFileManager.defaultManager()
        var isDir : ObjCBool = false
        let fileExists = fm.fileExistsAtPath(path, isDirectory:&isDir)
        if fileExists {
            return Bool(isDir)
        }
        
        // create file
        
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
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
            alert.addButtonWithTitle("OK")
            alert.alertStyle = .CriticalAlertStyle
            
            let modalResponse = alert.runModal()
            
            if modalResponse == NSAlertFirstButtonReturn {
                NSApplication.sharedApplication().terminate(self)
                return
            }
            
            return
        }
        
        self.screenShooter = existingScreenShooter
        screenShooter.makeScreenshotsAndConsolidate(nil)
        
        let timeInterval = NSUserDefaults.standardUserDefaults().integerForKey("SecondsBetweenScreenshots")
        
        self.timer.invalidate()
        self.timer = NSTimer.scheduledTimerWithTimeInterval(
            NSTimeInterval(timeInterval),
            target: screenShooter,
            selector: "makeScreenshotsAndConsolidate:",
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
        startAtLoginMenuItem.state = startAtLogin ? NSOnState : NSOffState;
    }
    
    func updateSkipScreensaverMenuItemState() {
        let skipScreensaver = NSUserDefaults.standardUserDefaults().boolForKey("SkipScreensaver")
        skipScreensaverMenuItem.state = skipScreensaver ? NSOnState : NSOffState
    }
    
    func updatePauseCaptureMenuItemState() {
        let captureIsPaused = self.timer.valid == false
        pauseCaptureMenuItem.state = captureIsPaused ? NSOnState : NSOffState
    }
    
    @IBAction func about(sender:NSControl) {
        if let url = NSURL(string:"http://seriot.ch/screentime/") {
            NSWorkspace.sharedWorkspace().openURL(url)
        }
    }
    
    @IBAction func openFolder(sender:NSControl) {
        NSWorkspace.sharedWorkspace().openFile(dirPath)
    }
    
    @IBAction func toggleSkipScreensaver(sender:NSControl) {
        let skipScreensaver = NSUserDefaults.standardUserDefaults().boolForKey("SkipScreensaver")
        
        NSUserDefaults.standardUserDefaults().setBool(!skipScreensaver, forKey: "SkipScreensaver");
        
        NSUserDefaults.standardUserDefaults().synchronize()
        
        self.updateSkipScreensaverMenuItemState()
    }
    
    @IBAction func toggleStartAtLogin(sender:NSControl) {
        LaunchServicesHelper().toggleLaunchAtStartup()
        
        self.updateStartAtLaunchMenuItemState()
    }
    
    @IBAction func togglePause(sender:NSControl) {
        let captureWasPaused = self.timer.valid == false
        
        if captureWasPaused {
            self.startTimer()
        } else {
            self.stopTimer()
        }
        
        let imageName = captureWasPaused ? "ScreenTime" : "ScreenTimePaused"
        let iconImage = NSImage(named: imageName)!
        iconImage.template = true
        self.statusItem.image = iconImage
        
        self.updatePauseCaptureMenuItemState()
    }
    
    @IBAction func quit(sender:NSControl) {
        NSApplication.sharedApplication().terminate(self)
    }
    
    @IBAction func historySliderDidMove(slider:NSSlider) {
        
        let sliderValue = slider.integerValue
        print("-- \(sliderValue)")
        
        let s = AppDelegate.historyPeriodDescriptionForSliderValue(sliderValue)
        
        self.historyDepthTextField.stringValue = s
        
        let numberOfDays = AppDelegate.historyNumberOfDaysForSliderValue(sliderValue)
        
        NSUserDefaults.standardUserDefaults().setInteger(numberOfDays, forKey: "HistoryToKeepInDays")
    }
    
    func checkForUpdates() {
        
        let url = NSURL(string:"http://www.seriot.ch/screentime/screentime.json")
        
        NSURLSession.sharedSession().dataTaskWithURL(url!) { (optionalData, response, error) -> Void in
            
            dispatch_async(dispatch_get_main_queue(),{
                
                guard let data = optionalData,
                    optionalDict = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as? [String:AnyObject],
                    d = optionalDict else {
                    return
                }
                
                guard let latestVersionString = d["latest_version_string"] as? String else { return }
                guard let latestVersionURL = d["latest_version_url"] as? String else { return }
                
                print("-- latestVersionString: \(latestVersionString)")
                print("-- latestVersionURL: \(latestVersionURL)")
                
                let currentVersionString = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as? String
                
                let needsUpdate = currentVersionString < latestVersionString
                
                print("-- needsUpdate: \(needsUpdate)")
                if needsUpdate == false { return }
                
                let alert = NSAlert()
                alert.messageText = "ScreenTime \(latestVersionString) is Available"
                alert.informativeText = "Please download it and replace the current version.";
                alert.addButtonWithTitle("Download")
                alert.addButtonWithTitle("Cancel")
                alert.alertStyle = .CriticalAlertStyle
                
                let modalResponse = alert.runModal()
                
                if modalResponse == NSAlertFirstButtonReturn {
                    if let downloadURL = NSURL(string:latestVersionURL) {
                        NSWorkspace.sharedWorkspace().openURL(downloadURL)
                    }
                }
                
            })
            }.resume()
    }
    
    class func sliderValueForNumberOfDays(numberOfDays:Int) -> Int {
        
        if let i = self.historyDays.indexOf(numberOfDays) {
            return i
        }
        
        return 0
    }
    
    class func historyNumberOfDaysForSliderValue(value:Int) -> Int {
        
        if value >= self.historyDays.count {
            return 0
        }
        
        return self.historyDays[value]
    }
    
    class func historyPeriodDescriptionForSliderValue(value:Int) -> String {
        let i = self.historyNumberOfDaysForSliderValue(value)
        
        if i == 0 { return "Never" }
        if i == 1 { return "1 day" }
        
        return "\(i) days"
    }
    
    func updateHistoryDepthLabelDescription() {
        let numberOfDays = NSUserDefaults.standardUserDefaults().integerForKey("HistoryToKeepInDays")
        
        let sliderValue = AppDelegate.sliderValueForNumberOfDays(numberOfDays)
        
        let s = AppDelegate.historyPeriodDescriptionForSliderValue(sliderValue)
        
        historyDepthTextField.stringValue = s
    }
    
    func updateHistoryDepthSliderPosition() {
        let numberOfDays = NSUserDefaults.standardUserDefaults().integerForKey("HistoryToKeepInDays")
        historyDepthSlider.integerValue = AppDelegate.sliderValueForNumberOfDays(numberOfDays)
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(menu:NSMenu) {
        
        self.updateStartAtLaunchMenuItemState()
        
        if let modifierFlags = NSApp.currentEvent?.modifierFlags {
            let optionKeyIsPressed = (modifierFlags.rawValue & NSEventModifierFlags.AlternateKeyMask.rawValue) == NSEventModifierFlags.AlternateKeyMask.rawValue
            let commandKeyIsPressed = (modifierFlags.rawValue & NSEventModifierFlags.CommandKeyMask.rawValue) == NSEventModifierFlags.CommandKeyMask.rawValue
            if(optionKeyIsPressed && commandKeyIsPressed) {
                screenShooter.makeScreenshotsAndConsolidate(nil)
            }
            self.versionMenuItem.hidden = optionKeyIsPressed == false;
        }
        
        // build history contents according to file system's contents
        
        let subMenu = self.historyContentsMenuItem.submenu
        subMenu?.removeAllItems()
        
        let namesAndPaths = Consolidator.movies(dirPath)
        
        for (n,p) in namesAndPaths {
            let historyItem = subMenu?.addItemWithTitle(n, action: "historyItemAction:", keyEquivalent: "")
            historyItem?.representedObject = p
        }
    }
    
    func historyItemAction(menuItem:NSMenuItem) {
        if let path = menuItem.representedObject as? String {
            print("-- open \(path)")
            NSWorkspace().openFile(path)
        }
    }
}
