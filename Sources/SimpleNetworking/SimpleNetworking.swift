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
                let simpleResponse = SimpleResponse(
                    data: data,
                    response: response as? HTTPURLResponse
                )
                if let simpleResponse = simpleResponse {
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
        request.allHTTPHeaderFields = headers(for: simpleRequest)
        return request
    }

    private func headers(for simpleRequest: SimpleRequest) -> [String: String] {
        return defaultHeaders.merging(
            ["Accept": simpleRequest.acceptContentType.rawValue]
        ) {(old, _) in old }
    }
}

extension SimpleNetworking {
    open func get(_ path: String, _ requestBuilder: SimpleRequestBuilder) {
        execute(request: requestBuilder(SimpleNetworking.get(path)))
    }

    open class func get(_ path: String) -> SimpleRequest {
        return SimpleRequest(path: path, httpMethod: .get)
    }
}

extension SimpleNetworking: CustomStringConvertible {
    public var description: String {
        return "SimpleNetworking<baseURL: \"\(baseURL)\">"
    }
}
