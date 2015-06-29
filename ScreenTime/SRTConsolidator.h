//
//  SRTConsolidator.h
//  ScreenTime
//
//  Created by Nicolas Seriot on 20/06/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SRTConsolidator : NSObject

+ (instancetype)consolidatorWithDirPath:(NSString *)dirPath;

- (void)consolidateScreenshotsIntoHourMovies;

- (void)consolidateHourMoviesIntoDayMovies;

// for unit tests

+ (NSArray *)filterFilenames:(NSArray *)paths
               directoryPath:(NSString *)dirPath
                     withExt:(NSString *)ext
             timestampLength:(NSUInteger)timestampLength
                beforeString:(NSString *)beforeString
     groupedByPrefixOfLength:(NSUInteger)groupPrefixLength;

@end
