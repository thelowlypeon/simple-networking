//
//  RequestTests.swift
//  SimpleNetworkingTests
//
//  Created by Peter Compernolle on 8/25/19.
//  Copyright © 2019 Peter Compernolle. All rights reserved.
//

import XCTest
@testable import SimpleNetworking

class RequestTests: XCTestCase {

    let timeout = 2
    var manager: SimpleNetworking!

    override func setUp() {
        manager = SimpleNetworking(baseURL: URL(string: "https://httpbin.org")!)
    }

    func testGET() {
        let expectation = self.expectation(description: "Received successful GET")
        var response: SimpleResponse?
        manager.get("/get?param=value") {(request) in
            return request
                .accept(.json)
                .on(error: {(error, _) in
                    XCTFail("failed with error \(error)")
                })
                .on(success: {(resp) in
                    response = resp
                    expectation.fulfill()
                })
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.json?["url"] as? String, "https://httpbin.org/get?param=value")
    }

    func testAuthenticationChallenge() {
        let expectation = self.expectation(description: "Authenticated successfully")
        var response: SimpleResponse?
        var continuedAfterError = false
        let user = "test-user"
        let password = "test-password"
        manager.get("/basic-auth/\(user)/\(password)") {(request) in
            return request.on(httpStatus: 401, {(req, res) in
                self.manager.authenticate(with: user, password: password)
                req.retry(on: self.manager)
                return false
            }).on(error: {(err, _) in
                continuedAfterError = true
            }).on(success: {(res) in
                response = res
                expectation.fulfill()
            })
        }
        waitForExpectations(timeout: 3, handler: nil)
        XCTAssertNotNil(response)
        XCTAssertFalse(continuedAfterError)
        XCTAssertTrue(response?.json?["authenticated"] as? Bool ?? false)
    }

    func testHTTPStatusHandlerContinues() {
        let expectation = self.expectation(description: "Handled status code correctly")
        var handledStatus = false
        var error: SimpleNetworkingError?
        manager.get("/status/499") {(request) in
            return request.on(httpStatus: 499, {(req, res) in
                handledStatus = true
                return true
            }).on(error: {(err, _) in
                error = err
                expectation.fulfill()
            })
        }
        waitForExpectations(timeout: 3, handler: nil)
        XCTAssertNotNil(error)
        XCTAssert(handledStatus)
    }

    func testHeadersAreSent() {
        manager.defaultHeaders["Header1"] = "Value1"
        manager.defaultHeaders["Header2"] = "Value2"
        let expectation = self.expectation(description: "Received response with headers")
        var response: SimpleResponse?
        manager.get("/headers") {(request) in
            return request
                .accept(.json)
                .on(success: {(resp) in
                    response = resp
                    expectation.fulfill()
                })
        }
        waitForExpectations(timeout: 1, handler: nil)
        if let actualHeaders = response?.json?["headers"] as? Dictionary<String, String> {
            XCTAssertEqual(actualHeaders["Header1"], "Value1")
            XCTAssertEqual(actualHeaders["Header2"], "Value2")
        } else {
            XCTFail("No headers were sent (or httpbin messed up")
        }
    }

    func testGETRequestFollowsRedirects() {
        let expectation = self.expectation(description: "Received redirect")
        var response: SimpleResponse?
        manager.get("/redirect-to?url=https%3A%2F%2Fhttpbin.org%2Fget&status_code=301") {(request) in
            return request
                .accept(.json)
                .on(success: {(resp) in
                    response = resp
                    expectation.fulfill()
                })
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.json?["url"] as? String, "https://httpbin.org/get")
    }

    func testGETRequestServerSideError() {
        let expectation = self.expectation(description: "Received redirect")
        var error: SimpleNetworkingError?
        manager.get("/status/404") {(request) in
            return request
                .on(error: {(err) in
                    error = err
                    expectation.fulfill()
                })
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNotNil(error)
        switch error! {
        case .clientError(let status):
            XCTAssertEqual(status, 404)
        default:
            XCTFail("unexpected error \(error!)")
        }
    }

    func testGETRequestServerSideErrorWithResponse() {
        let expectation = self.expectation(description: "Received redirect")
        var response: SimpleResponse?
        manager.get("/status/404") {(request) in
            return request
                .on(error: {(_, resp) in
                    response = resp
                    expectation.fulfill()
                })
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNotNil(response)
        XCTAssertNotNil(response!.error)
        switch response!.error! {
        case .clientError(let status):
            XCTAssertEqual(status, 404)
        default:
            XCTFail("unexpected error \(response!.error!)")
        }
    }
}
