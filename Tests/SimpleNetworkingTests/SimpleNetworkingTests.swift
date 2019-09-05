//
//  SimpleNetworkingTests.swift
//  SimpleNetworkingTests
//
//  Created by Peter Compernolle on 8/24/19.
//  Copyright © 2019 Peter Compernolle. All rights reserved.
//

import XCTest
@testable import SimpleNetworking

class MockURLSession: URLSession {
    let buildDataTaskHandler: ((URLRequest) -> Void)?
    let mockDataTask: MockURLSessionDataTask

    init(buildDataTaskHandler: ((URLRequest) -> Void)?, mockDataTask: MockURLSessionDataTask) {
        self.buildDataTaskHandler = buildDataTaskHandler
        self.mockDataTask = mockDataTask
        super.init()
    }

    override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        buildDataTaskHandler?(request)
        return mockDataTask
    }
}

class MockURLSessionDataTask: URLSessionDataTask {
    let resumeHandler: (() -> Void)?

    init(resumeHandler: (() -> Void)? = nil) {
        self.resumeHandler = resumeHandler
        super.init()
    }
    override func resume() {
        resumeHandler?()
    }
}

class SimpleNetworkingTests: XCTestCase {
    let baseURL = URL(string: "https://httpbin.org")!
    let path = "/get"
    let headers = ["header1": "value1", "header2": "value2"]

    func manager() -> SimpleNetworking {
        return SimpleNetworking(baseURL: baseURL, defaultHeaders: headers)
    }

    func mockManager(dataTask: MockURLSessionDataTask? = nil, buildDataTaskHandler: ((URLRequest) -> Void)? = nil) -> SimpleNetworking {
        let dataTask = dataTask ?? MockURLSessionDataTask()
        let session = MockURLSession(buildDataTaskHandler: buildDataTaskHandler, mockDataTask: dataTask)
        return SimpleNetworking(baseURL: baseURL, session: session, defaultHeaders: headers)
    }

    func testStaticGET() {
        let request = SimpleNetworking.get(path)
        XCTAssertEqual(request.path, path)
        XCTAssertEqual(request.httpMethod, .get)
    }

    func testInstanceGetCreatesRequest() {
        let expectation = self.expectation(description: "GET request is built")
        var request: SimpleRequest?
        mockManager().get(path) {(req) in
            request = req
            expectation.fulfill()
            return req
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(request?.path, path)
        XCTAssertEqual(request?.httpMethod, .get)
    }

    func testGetBuildsURLRequest() {
        let expectation = self.expectation(description: "URLRequest is built")
        var request: URLRequest?
        let manager = mockManager(dataTask: nil, buildDataTaskHandler: {(urlRequest) in
            request = urlRequest
            expectation.fulfill()
        })
        manager.get(path) {(request) in return request }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNotNil(request)
    }

    func testGetBuildsURLRequestWithURLAndMethod() {
        let expectation = self.expectation(description: "URLRequest is built")
        var httpMethod: String?
        var url: URL?
        let manager = mockManager(dataTask: nil, buildDataTaskHandler: {(urlRequest) in
            httpMethod = urlRequest.httpMethod
            url = urlRequest.url
            expectation.fulfill()
        })
        manager.get(path) {(request) in return request }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(httpMethod, "GET")
        XCTAssertEqual(url?.absoluteString, "\(baseURL)\(path)")
    }

    func testGetBuildsURLRequestWithHeaders() {
        let expectation = self.expectation(description: "URLRequest is built")
        var actualHeaders: [String: String]?
        let manager = mockManager(dataTask: nil, buildDataTaskHandler: {(urlRequest) in
            actualHeaders = urlRequest.allHTTPHeaderFields
            expectation.fulfill()
        })
        manager.get(path) {(request) in return request.accept(.json) }
        waitForExpectations(timeout: 1, handler: nil)
        for (key, value) in headers {
            XCTAssertEqual(actualHeaders?[key], value)
        }
        XCTAssertEqual(actualHeaders?["Accept"], SimpleRequest.ContentType.json.rawValue)
    }

    func testGetExecutesURLRequest() {
        let expectation = self.expectation(description: "URLRequest is executed")
        let mockDataTask = MockURLSessionDataTask(resumeHandler: {() in
            expectation.fulfill()
        })
        let manager = mockManager(dataTask: mockDataTask)
        manager.get(path) {(request) in return request }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testSuccessfulGET() {
        let expectation = self.expectation(description: "GET request succeeded")
        var response: SimpleResponse?
        manager().get("/get") {(request) in
            return request.on(success: {(resp) in
                response = resp
                expectation.fulfill()
            })
        }
        waitForExpectations(timeout: 3, handler: nil)
        XCTAssertNotNil(response)
        XCTAssertTrue(response?.success ?? false)
    }

    func testNetworkingErrorGET() {
        let expectation = self.expectation(description: "GET request failed")
        var error: SimpleNetworkingError?
        SimpleNetworking(baseURL: URL(string: "http://invaliddomain.com")!).get("/404") {(request) in
            return request.on(error: {(err) in
                error = err
                expectation.fulfill()
            })
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNotNil(error)
        switch error! {
        case .networkingError(let err):
            XCTAssertNotNil(err)
        default:
            XCTFail("Expected networking error, got \(error!)")
        }
    }

}
