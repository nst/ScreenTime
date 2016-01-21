//
//  NSDateExtension.swift
//  ScreenTime
//
//  Created by nst on 10/01/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Foundation

extension NSDate {

    private static var srt_timestampDateFormatter : NSDateFormatter {
        let df = NSDateFormatter()
        df.dateFormat = "yyyyMMddHHmmss"
        return df
    }

    private static var srt_prettyDateFormatter : NSDateFormatter {
        let df = NSDateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }

    func srt_timestamp() -> String {
        return NSDate.srt_timestampDateFormatter.stringFromDate(self)
    }
    
    class func srt_prettyDateFromTimestamp(timestamp:String) -> String {
        let date = NSDate.srt_timestampDateFormatter.dateFromString(timestamp)
        return NSDate.srt_prettyDateFormatter.stringFromDate(date!)
    }
}