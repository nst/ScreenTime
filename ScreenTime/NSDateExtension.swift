//
//  NSDateExtension.swift
//  ScreenTime
//
//  Created by nst on 10/01/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Foundation

extension Date {

    fileprivate static var srt_longTimestampDateFormatter : DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMddHHmmss"
        return df
    }

    fileprivate static var srt_mediumTimestampDateFormatter : DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMddHH"
        return df
    }

    fileprivate static var srt_shortTimestampDateFormatter : DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        return df
    }

    fileprivate static var srt_prettyDateMediumFormatter : DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:00"
        return df
    }
    
    fileprivate static var srt_prettyDateLongFormatter : DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }

    fileprivate static var srt_prettyDateShortFormatter : DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd E"
        return df
    }
    
    func srt_timestamp() -> String {
        return Date.srt_longTimestampDateFormatter.string(from: self)
    }

    static func srt_prettyDateFromShortTimestamp(_ timestamp:String) -> String? {
        guard let date = Date.srt_shortTimestampDateFormatter.date(from: timestamp) else {
            print("-- cannot convert short timestamp \(timestamp) into short date string")
            return nil
        }
        return Date.srt_prettyDateShortFormatter.string(from: date)
    }

    static func srt_prettyDateFromMediumTimestamp(_ timestamp:String) -> String? {
        guard let date = Date.srt_mediumTimestampDateFormatter.date(from: timestamp) else {
            print("-- cannot convert medium timestamp \(timestamp) into medium date string")
            return nil
        }
        return Date.srt_prettyDateMediumFormatter.string(from: date)
    }

    static func srt_prettyDateFromLongTimestamp(_ timestamp:String) -> String? {
        guard let date = Date.srt_longTimestampDateFormatter.date(from: timestamp) else {
            print("-- cannot convert long timestamp \(timestamp) into long date string")
            return nil
        }
        return Date.srt_prettyDateLongFormatter.string(from: date)
    }
}
