//
//  SimpleNetworking.swift
//  SimpleNetworking
//
//  Created by Peter Compernolle on 8/24/19.
//  Copyright © 2019 Peter Compernolle. All rights reserved.
//

import Foundation

public enum SimpleNetworkingError: Error {
    case invalidURL
    case noResponse
    case networkingError(Error?)
    case clientError(Int)
    case serverError(Int)
    case invalidResponse
    case unknown(String) // for debugging
}

public typealias SimpleRequestBuilder = (SimpleRequest) -> SimpleRequest

open class SimpleNetworking {

    public let baseURL: URL

    public let maxRetries: Int

    public var defaultHeaders: [String: String]

    private let session: URLSession

    private static let defaultMaxTries = 3

    public init(baseURL: URL,
                session: URLSession? = nil,
                maxRetries: Int? = nil,
                defaultHeaders: [String: String]? = nil) {
        self.baseURL = baseURL
        self.session = session ?? URLSession(configuration: .ephemeral)
        self.maxRetries = maxRetries ?? SimpleNetworking.defaultMaxTries
        self.defaultHeaders = defaultHeaders ?? [String: String]()
    }

    open func authenticate(with user: String, password: String) {
        let base64EncodedAuth = Data("\(user):\(password)".utf8).base64EncodedString()
        self.defaultHeaders["Authorization"] = "Basic \(base64EncodedAuth)"
    }

    open func execute(request simpleRequest: SimpleRequest) {
        guard let urlRequest = buildURLRequest(from: simpleRequest) else {
            simpleRequest.didReceive(error: .invalidURL, response: nil)
            return
        }
        session.dataTask(
            with: urlRequest
        ) {(data, response, error) in
            if let error = error {
                simpleRequest.didReceive(error: .networkingError(error), response: nil)
            } else {
                if let simpleResponse = SimpleResponse(data: data, response: response as? HTTPURLResponse) {
                    simpleRequest.didReceive(response: simpleResponse)
                } else {
                    simpleRequest.didReceive(error: .invalidResponse, response: nil)
                }
            }
        }.resume()
    }

    private func buildURLRequest(from simpleRequest: SimpleRequest) -> URLRequest? {
        guard let url = simpleRequest.url(baseURL: baseURL) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = simpleRequest.httpMethod.rawValue
        request.allHTTPHeaderFields = defaultHeaders
            .merging(simpleRequest.headers()) {(_, new) in new}
        request.httpBody = simpleRequest.body
        return request
    }
}

extension SimpleNetworking {
    open func get(_ path: String, queryParams: [String: String?]? = nil, headers: [String: String]? = nil, _ requestBuilder: SimpleRequestBuilder) {
        execute(request: requestBuilder(SimpleNetworking.get(path, queryParams: queryParams, headers: headers)))
    }

    open class func get(_ path: String, queryParams: [String: String?]? = nil,  headers: [String: String]? = nil) -> SimpleRequest {
        return SimpleRequest(path: path, httpMethod: .get, queryParams: queryParams, headers: headers)
    }

    open func post(_ path: String, body: Data? = nil, queryParams: [String: String?]? = nil, headers: [String: String]? = nil, _ requestBuilder: SimpleRequestBuilder) {
        execute(request: requestBuilder(SimpleNetworking.post(path, body: body, queryParams: queryParams, headers: headers)))
    }

    open class func post(_ path: String, body: Data? = nil, queryParams: [String: String?]? = nil, headers: [String: String]? = nil) -> SimpleRequest {
        return SimpleRequest(path: path, httpMethod: .post, queryParams: queryParams, body: body, headers: headers)
    }
}

extension SimpleNetworking: CustomStringConvertible {
    public var description: String {
        return "SimpleNetworking<baseURL: \"\(baseURL)\">"
    }
}
