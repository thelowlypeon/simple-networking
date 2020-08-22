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
        manager.get("/get", queryParams: ["param": "value"]) {(request) in
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
        if let dict = response?.json as? Dictionary<String, Any> {
            XCTAssertEqual(dict["url"] as? String, "https://httpbin.org/get?param=value")
        } else {
            XCTFail("JSON dict casting failed")
        }
    }

    func testPOST() {
        let expectation = self.expectation(description: "Sent successful POST")
        var response: SimpleResponse?
        manager.post("/post", queryParams: ["queryParam": "value"]) {(request) in
            return request
                .body(json: ["bodyKey": "bodyValue"])
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
        if let dict = response?.json as? Dictionary<String, Any> {
            XCTAssertEqual(dict["url"] as? String, "https://httpbin.org/post?queryParam=value")
            print(dict)
            if let json = dict["json"] as? Dictionary<String, String> {
                XCTAssertEqual(json["bodyKey"], "bodyValue")
            } else {
                XCTFail("Did not receive POST body")
            }
        } else {
            XCTFail("JSON dict casting failed")
        }
    }

    func testDecode() {
        struct Container: Decodable {
            let slideshow: Slideshow
            enum CodingKeys: String, CodingKey {
                case slideshow = "slideshow"
            }
        }
        struct Slideshow: Decodable {
            let author: String
            enum CodingKeys: String, CodingKey {
                case author = "author"
            }
        }
        let expectation = self.expectation(description: "Received successful GET")
        var instance: Container?
        manager.get("/json") {(request) in
            return request
                .accept(.json)
                .on(error: {(error, _) in
                    XCTFail("failed with error \(error)")
                })
                .on(success: {(resp) in
                    instance = resp.decodeJSON()
                    expectation.fulfill()
                })
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNotNil(instance)
        XCTAssertEqual(instance?.slideshow.author, "Yours Truly")
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
        XCTAssertTrue((response?.json as? Dictionary<String, Any>)?["authenticated"] as? Bool ?? false)
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
        if let actualHeaders = (response?.json as? Dictionary<String, Any>)?["headers"] as? Dictionary<String, String> {
            XCTAssertEqual(actualHeaders["Header1"], "Value1")
            XCTAssertEqual(actualHeaders["Header2"], "Value2")
        } else {
            XCTFail("No headers were sent (or httpbin messed up")
        }
    }

    func testBasicAuthenticationHeaderIsSent() {
        let expectation = self.expectation(description: "Received response with headers")
        var response: SimpleResponse?
        manager.get("/headers") {(request) in
            return request
                .authenticateBasic(user: "username", password: "password")
                .accept(.json)
                .on(success: {(resp) in
                    response = resp
                    expectation.fulfill()
                })
        }
        waitForExpectations(timeout: 1, handler: nil)
        if let actualHeaders = (response?.json as? Dictionary<String, Any>)?["headers"] as? Dictionary<String, String> {
            XCTAssertEqual(actualHeaders["Authorization"], "Basic dXNlcm5hbWU6cGFzc3dvcmQ=")
        } else {
            XCTFail("No headers were sent (or httpbin messed up")
        }
    }

    func testAuthenticationHeaderIsSent() {
        let expectation = self.expectation(description: "Received response with headers")
        var response: SimpleResponse?
        manager.get("/headers") {(request) in
            return request
                .authenticate(withHeader: "my-token")
                .accept(.json)
                .on(success: {(resp) in
                    response = resp
                    expectation.fulfill()
                })
        }
        waitForExpectations(timeout: 1, handler: nil)
        if let actualHeaders = (response?.json as? Dictionary<String, Any>)?["headers"] as? Dictionary<String, String> {
            XCTAssertEqual(actualHeaders["Authorization"], "my-token")
        } else {
            XCTFail("No headers were sent (or httpbin messed up")
        }
    }

    func testGETRequestFollowsRedirects() {
        let expectation = self.expectation(description: "Received redirect")
        var response: SimpleResponse?
        let params = ["url": "https://httpbin.org/get", "status_code": "301"]
        manager.get("/redirect-to", queryParams: params) {(request) in
            return request
                .accept(.json)
                .on(success: {(resp) in
                    response = resp
                    expectation.fulfill()
                })
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNotNil(response)
        XCTAssertEqual((response?.json as? Dictionary<String, Any>)?["url"] as? String, "https://httpbin.org/get")
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
