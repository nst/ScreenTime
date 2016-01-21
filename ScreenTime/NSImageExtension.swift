//
//  NSImageExtension.swift
//  ScreenTime
//
//  Created by nst on 10/01/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import AppKit

extension NSImage {
    func srt_writeAsJpeg(path:String) -> Bool {
        guard let imageData = self.TIFFRepresentation else { return false }
        let bitmapRep = NSBitmapImageRep(data: imageData)
        guard let jpegData = bitmapRep?.representationUsingType(.NSJPEGFileType, properties: [NSImageCompressionFactor : 0.8]) else { return false }
        do {
            try jpegData.writeToFile(path, options: .AtomicWrite)
        } catch {
            print("-- can't write, error", error)
            return false
        }
        return true
    }
}