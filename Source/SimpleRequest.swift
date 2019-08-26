//
//  SimpleRequest.swift
//  SimpleNetworking
//
//  Created by Peter Compernolle on 8/24/19.
//  Copyright © 2019 Peter Compernolle. All rights reserved.
//

import Foundation

public class SimpleRequest {
    public enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    public enum ContentType: String {
        case json = "application/json"
        case text = "application/text"
    }

    public typealias SimpleHTTPStatusHandler = (SimpleRequest, SimpleResponse) -> Bool
    public typealias SimpleResponseHandler = (SimpleResponse) -> Void
    public typealias SimpleErrorHandler = (SimpleNetworkingError) -> Void

    public let path: String

    public let httpMethod: HTTPMethod

    public var retries = 0

    public var acceptContentType: ContentType = .json

    private var httpStatusHandlers = [Int: SimpleHTTPStatusHandler]()
    private var responseHandlers = [SimpleResponseHandler]()
    private var errorHandlers = [SimpleErrorHandler]()

    public init(path: String, httpMethod: HTTPMethod) {
        self.path = path
        self.httpMethod = httpMethod
    }

    public func accept(_ contentType: ContentType) -> Self {
        self.acceptContentType = contentType
        return self
    }

    public func url(baseURL: URL) -> URL {
        return URL(string: path, relativeTo: baseURL)!
    }
}

public class SimpleRequestGET: SimpleRequest {
    let queryParameters: [String: String]

    public init(path: String, params: [String: String] = [String: String]()) {
        self.queryParameters = params
        super.init(path: path, httpMethod: .get)
    }
}

// execution
extension SimpleRequest {
    public func execute(on manager: SimpleNetworking) {
        manager.execute(request: self)
    }

    public func retry(on manager: SimpleNetworking) {
        guard retries < manager.maxRetries else { return }
        retries += 1
        manager.execute(request: self)
    }
}

// managing handlers
extension SimpleRequest {
    public func on(httpStatus: Int, _ handler: @escaping SimpleHTTPStatusHandler) -> Self {
        httpStatusHandlers[httpStatus] = handler
        return self
    }

    public func handles(httpStatus: Int) -> Bool {
        return httpStatusHandlers[httpStatus] != nil
    }

    public func on(error handler: @escaping SimpleErrorHandler) -> Self {
        errorHandlers.append(handler)
        return self
    }

    public func on(success handler: @escaping SimpleResponseHandler) -> Self {
        responseHandlers.append(handler)
        return self
    }
}

// upon getting a response
extension SimpleRequest {
    internal func didReceive(response: SimpleResponse) {
        guard shouldContinueUponReceiving(response) else { return }

        let error: SimpleNetworkingError? = response.validFor(contentType: acceptContentType) ? response.error : .invalidResponse

        if let error = error {
            didReceive(error: error)
        } else if response.success {
            didReceive(success: response)
        }
    }

    internal func didReceive(error: SimpleNetworkingError) {
        for handler in errorHandlers {
            handler(error)
        }
    }

    internal func didReceive(success response: SimpleResponse) {
        for handler in responseHandlers {
            handler(response)
        }
    }

    private func shouldContinueUponReceiving(_ response: SimpleResponse) -> Bool {
        if let httpStatusHandler = self.httpStatusHandlers[response.httpStatus] {
            return httpStatusHandler(self, response)
        }
        return true
    }
}

extension SimpleRequest: CustomStringConvertible {
    public var description: String {
        return "SimpleRequest<\(httpMethod.rawValue) \"\(path)\">"
    }
}
