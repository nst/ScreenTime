//
//  NSDate+SRT.h
//  ScreenTime
//
//  Created by Nicolas Seriot on 20/06/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (SRT)

- (NSString *)srt_timestamp;
+ (NSString *)srt_prettyDateFromTimestamp:(NSString *)timestamp;

@end
