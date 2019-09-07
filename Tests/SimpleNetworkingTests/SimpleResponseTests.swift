//
//  SimpleResponseTests.swift
//  SimpleNetworkingTests
//
//  Created by Peter Compernolle on 8/25/19.
//  Copyright © 2019 Peter Compernolle. All rights reserved.
//

import XCTest
@testable import SimpleNetworking

class SimpleResponseTests: XCTestCase {

    let successURLResponse = HTTPURLResponse(
        url: URL(string: "...")!,
        statusCode: 200,
        httpVersion: "2.0",
        headerFields: nil
    )

    let jsonData = try! JSONEncoder().encode(["key": "value"])
    let textData = Data("not json".utf8)

    func testSuccessResponseSuccess() {
        let response = SimpleResponse(data: nil, response: successURLResponse)!
        XCTAssert(response.success)
        XCTAssertNil(response.error)
    }

    func testServerErrorStatusCode() {
        let serverErrorURLResponse = HTTPURLResponse(
            url: URL(string: "...")!,
            statusCode: 500,
            httpVersion: "2.0",
            headerFields: nil
        )
        let response = SimpleResponse(data: nil, response: serverErrorURLResponse)!
        XCTAssertFalse(response.success)
        XCTAssertNotNil(response.error)
        switch response.error! {
        case .serverError(let status):
            XCTAssertEqual(status, 500)
        default:
            XCTFail("Expected server error, got \(response.error!)")
        }
    }

    func testClientErrorStatusCode() {
        let clientErrorURLResponse = HTTPURLResponse(
            url: URL(string: "...")!,
            statusCode: 400,
            httpVersion: "2.0",
            headerFields: nil
        )
        let response = SimpleResponse(data: nil, response: clientErrorURLResponse)!
        XCTAssertFalse(response.success)
        XCTAssertNotNil(response.error)
        switch response.error! {
        case .clientError(let status):
            XCTAssertEqual(status, 400)
        default:
            XCTFail("Expected client error, got \(response.error!)")
        }
    }

    func testWeirdStatusCodeWithNilData() {
        let weirdStatusResponse = HTTPURLResponse(
            url: URL(string: "...")!,
            statusCode: 0,
            httpVersion: "2.0",
            headerFields: nil
        )
        let response = SimpleResponse(data: nil, response: weirdStatusResponse)!
        XCTAssertFalse(response.success)
        XCTAssertNotNil(response.error)
        switch response.error! {
        case .invalidResponse:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected no response error, got \(response.error!)")
        }
    }
}
