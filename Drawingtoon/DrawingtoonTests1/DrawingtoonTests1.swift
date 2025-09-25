//
//  DrawingtoonTests1.swift
//  DrawingtoonTests1
//
//  Created by Heejung Yang on 9/24/25.
//

import XCTest
import Drawingtoon

final class DrawingtoonTests1: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testRequestResponse_withExpectation() {
        // given
        let url = Endpoint.get.url
        let exp = expectation(description: "DataRequest.response")
        var result: Data?

        // when
        NT.request(url, parameters: ["foo": "bar"])
            .response { data in
                result = data
                exp.fulfill()
            }

        // then
        waitForExpectations(timeout: 5.0)
        XCTAssertNotNil(result)
        // XCTAssertGreaterThan(result?.count ?? 0, 0)
    }

    func testExample() throws {

    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}


