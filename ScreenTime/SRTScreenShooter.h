//
//  SRTScreenShooter.h
//  ScreenTime
//
//  Created by Nicolas Seriot on 26/06/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SRTScreenShooter : NSObject

@property (nonatomic, strong) NSString *directoryPath;

- (instancetype)initWithDirectory:(NSString *)path;

- (void)makeScreenshotsAndConsolidate;

- (void)removeFilesOlderThanNumberOfDays:(NSUInteger)maxAgeInDays;

@end
