//
//  NSDateExtension.swift
//  ScreenTime
//
//  Created by nst on 10/01/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Foundation

extension Date {

    fileprivate static var srt_timestampDateFormatter : DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMddHHmmss"
        return df
    }

    fileprivate static var srt_prettyDateFormatter : DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }

    func srt_timestamp() -> String {
        return Date.srt_timestampDateFormatter.string(from: self)
    }
    
    static func srt_prettyDateFromTimestamp(_ timestamp:String) -> String {
        let date = Date.srt_timestampDateFormatter.date(from: timestamp)
        return Date.srt_prettyDateFormatter.string(from: date!)
    }
}
