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
        case html = "application/html"

        public func header() -> [String: String] {
            return ["Content-Type": self.rawValue]
        }

        public func acceptHeader() -> [String: String] {
            return ["Accept": self.rawValue]
        }
    }

    public typealias SimpleHTTPStatusHandler = (SimpleRequest, SimpleResponse) -> Bool
    public typealias SimpleResponseHandler = (SimpleResponse) -> Void
    public typealias SimpleErrorHandlerWithResponse = (SimpleNetworkingError, SimpleResponse?) -> Void
    public typealias SimpleErrorHandler = (SimpleNetworkingError) -> Void

    public let path: String

    public let queryParams: [String: String?]?

    public var body: Data?

    public var additionalHeaders: [String: String]

    public let httpMethod: HTTPMethod

    public var retries = 0

    public var acceptContentType: ContentType = .json

    public var contentType: ContentType = .json

    private var httpStatusHandlers = [Int: SimpleHTTPStatusHandler]()
    private var responseHandlers = [SimpleResponseHandler]()
    private var errorHandlers = [SimpleErrorHandler]()
    private var errorHandlersWithResponse = [SimpleErrorHandlerWithResponse]()


    public init(
        path: String,
        httpMethod: HTTPMethod,
        queryParams: [String: String?]? = nil,
        body: Data? = nil,
        headers: [String: String]? = nil
    ) {
        self.path = path
        self.queryParams = queryParams
        self.httpMethod = httpMethod
        self.body = body
        self.additionalHeaders = headers ?? [:]
    }

    public func accept(_ contentType: ContentType) -> Self {
        self.acceptContentType = contentType
        return self
    }

    public func body(json jsonObject: Any) -> Self {
        return body(data: try? JSONSerialization.data(withJSONObject: jsonObject), contentType: .json)
    }

    public func body(data: Data?, contentType: ContentType) -> Self {
        self.contentType = contentType
        self.body = data
        return self
    }

    open func authenticateBasic(user: String, password: String, at headerName: String? = nil) -> Self {
        let base64EncodedAuth = Data("\(user):\(password)".utf8).base64EncodedString()
        return self.authenticate(
            withHeader: "Basic \(base64EncodedAuth)",
            at: headerName ?? "Authorization"
        )
    }

    public func authenticate(withHeader value: String, at headerName: String? = nil) -> Self {
        self.additionalHeaders[headerName ?? "Authorization"] = value
        return self
    }

    public func headers() -> [String: String] {
        return additionalHeaders
            .merging(self.contentType.header()) {(_, new) in new}
            .merging(self.acceptContentType.acceptHeader()) {(_, new) in new}
    }

    public func url(baseURL: URL) -> URL? {
        guard var components = URLComponents(string: baseURL.absoluteString) else { return nil }
        components.path = components.path + path
        components.queryItems = queryParams?.map({(key, value) in
            return URLQueryItem(name: key, value: value)
        })
        return components.url
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

    public func on(error handler: @escaping SimpleErrorHandlerWithResponse) -> Self {
        errorHandlersWithResponse.append(handler)
        return self
    }
}

// upon getting a response
extension SimpleRequest {
    internal func didReceive(response: SimpleResponse) {
        guard shouldContinueUponReceiving(response) else { return }

        if let error = response.error {
            didReceive(error: error, response: response)
        } else if response.success {
            didReceive(success: response)
        }
    }

    internal func didReceive(error: SimpleNetworkingError, response: SimpleResponse?) {
        for handler in errorHandlers {
            handler(error)
        }
        for handler in errorHandlersWithResponse {
            handler(error, response)
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
