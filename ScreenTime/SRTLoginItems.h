//
//  SRTLoginItems.h
//  ScreenTime
//
//  Created by Nicolas Seriot on 27/06/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SRTLoginItems : NSObject

+ (void)enableLoginItem;
+ (void)disableLoginItem;
+ (BOOL)loginItemIsEnabled;

@end
