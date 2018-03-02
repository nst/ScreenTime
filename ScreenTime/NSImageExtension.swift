//
//  NSImageExtension.swift
//  ScreenTime
//
//  Created by nst on 10/01/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import AppKit

extension NSImage {
    func srt_writeAsJpeg(_ path:String) -> Bool {
        guard let imageData = self.tiffRepresentation else { return false }
        let bitmapRep = NSBitmapImageRep(data: imageData)
        guard let jpegData = bitmapRep?.representation(using:.jpeg, properties: [.compressionFactor : 0.8]) else { return false }
        do {
            try jpegData.write(to: URL(fileURLWithPath:path))
        } catch {
            print("-- can't write, error", error)
            return false
        }
        return true
    }
}
