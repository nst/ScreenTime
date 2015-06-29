//
//  NSDate+SRT.m
//  ScreenTime
//
//  Created by Nicolas Seriot on 20/06/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

#import "NSDate+SRT.h"

static NSDateFormatter *srt_timestampDateFormatter = nil;
static NSDateFormatter *srt_prettyDateFormatter = nil;

@implementation NSDate (SRT)

+ (NSDateFormatter *)srt_timestampDateFormatter {
    if(srt_timestampDateFormatter == nil) {
        srt_timestampDateFormatter = [[NSDateFormatter alloc] init];
        [srt_timestampDateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    }
    return srt_timestampDateFormatter;
}

+ (NSDateFormatter *)srt_prettyDateFormatter {
    if(srt_prettyDateFormatter == nil) {
        srt_prettyDateFormatter = [[NSDateFormatter alloc] init];
        [srt_prettyDateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    }
    return srt_prettyDateFormatter;
}

- (NSString *)srt_timestamp {
    
    NSDateFormatter *df = [[self class] srt_timestampDateFormatter];
    
    return [df stringFromDate:self];
}

+ (NSString *)srt_prettyDateFromTimestamp:(NSString *)timestamp {
    
    NSDateFormatter *df = [[self class] srt_timestampDateFormatter];
    
    NSDate *date = [df dateFromString:timestamp];
    
    NSDateFormatter *df2 = [[self class] srt_prettyDateFormatter];
    
    return [df2 stringFromDate:date];
}

@end
