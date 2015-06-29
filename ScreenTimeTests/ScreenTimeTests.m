//
//  ScreenTimeTests.m
//  ScreenTimeTests
//
//  Created by Nicolas Seriot on 28/06/15.
//  Copyright (c) 2015 Nicolas Seriot. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "SRTConsolidator.h"

@interface ScreenTimeTests : XCTestCase

@end

@implementation ScreenTimeTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    
    NSArray *filenames = @[@"20150601000000_111.jpg",
                           @"20150601000100_111.jpg",
                           @"20150601000000_123.jpg",
                           @"20150601000100_123.jpg",
                           @"20150615000000_111.jpg",
                           @"2015061510_111.mov",
                           @"2015061511_111.mov",
                           @"2015080110_111.mov"];
    
    NSArray *jpgGroups = [SRTConsolidator filterFilenames:filenames
                                            directoryPath:@"/tmp"
                                                  withExt:@"jpg"
                                          timestampLength:14
                                             beforeString:@"20150615"
                                  groupedByPrefixOfLength:10];
    
    NSArray *expectedJPGs = @[
                              @[@"/tmp/20150601000000_111.jpg",
                                @"/tmp/20150601000100_111.jpg"],
                              @[@"/tmp/20150601000000_123.jpg",
                                @"/tmp/20150601000100_123.jpg"]
                              ];
    
    XCTAssertEqualObjects(jpgGroups, expectedJPGs);
    
    NSArray *movGroups = [SRTConsolidator filterFilenames:filenames
                                            directoryPath:@"/tmp"
                                                  withExt:@"mov"
                                          timestampLength:10
                                             beforeString:@"20150701"
                                  groupedByPrefixOfLength:8];
    
    NSArray *expectedMOVs = @[
                              @[@"/tmp/2015061510_111.mov",
                                @"/tmp/2015061511_111.mov"]
                              ];
    
    XCTAssertEqualObjects(movGroups, expectedMOVs);
    
    XCTAssert(YES, @"Pass");
}

@end
