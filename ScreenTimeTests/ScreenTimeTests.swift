//
//  ScreenTimeTests.swift
//  ScreenTimeTests
//
//  Created by nst on 09/01/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import XCTest
@testable import ScreenTime

class ScreenTimeTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        let filenames = [
            "20150601000000_111.jpg",
            "20150601000100_111.jpg",
            "20150601000000_123.jpg",
            "20150601000100_123.jpg",
            "20150615000000_111.jpg",
            "2015061510_111.mov",
            "2015061511_111.mov",
            "2015080110_111.mov"]
        
        let jpgGroups = Consolidator.filterFilename(filenames,
            dirPath: "/tmp",
            withExt: "jpg",
            timestampLength: 14,
            beforeString: "20150615",
            groupedByPrefixOfLength: 10)
        
        let expectedJPGs = [
            ["/tmp/20150601000000_111.jpg", "/tmp/20150601000100_111.jpg"],
            ["/tmp/20150601000000_123.jpg", "/tmp/20150601000100_123.jpg"]
        ]
        
        XCTAssertEqual(jpgGroups.count, expectedJPGs.count)
        
        for (i,o1) in jpgGroups.enumerated() {
            let o2 = expectedJPGs[i]
            XCTAssertEqual(o1, o2)
        }
        
        /**/
        
        let movGroups = Consolidator.filterFilename(filenames,
            dirPath: "/tmp",
            withExt: "mov",
            timestampLength: 10,
            beforeString: "20150701",
            groupedByPrefixOfLength: 8)
        
        let expectedMOVs = [
            ["/tmp/2015061510_111.mov", "/tmp/2015061511_111.mov"]
        ]
        
        XCTAssertEqual(movGroups.count, expectedMOVs.count)
        
        for (i,o1) in movGroups.enumerated() {
            let o2 = expectedMOVs[i]
            XCTAssertEqual(o1, o2)
        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
