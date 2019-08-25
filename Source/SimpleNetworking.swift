//
//  SimpleNetworking.swift
//  SimpleNetworking
//
//  Created by Peter Compernolle on 8/24/19.
//  Copyright © 2019 Peter Compernolle. All rights reserved.
//

import Foundation

public enum SimpleNetworkingError: Error {
    case noResponse, networkingError(Error?), clientError(Int), serverError(Int), invalidResponse
}

public typealias SimpleRequestBuilder = (SimpleRequest) -> SimpleRequest

public class SimpleNetworking {

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

    public func execute(request simpleRequest: SimpleRequest) {
        session.dataTask(
            with: buildURLRequest(from: simpleRequest)
        ) {(data, response, error) in
            if let error = error {
                simpleRequest.didReceive(error: .networkingError(error))
            } else {
                let simpleResponse = SimpleResponse(
                    data: data,
                    response: response as? HTTPURLResponse
                )
                if let simpleResponse = simpleResponse {
                    simpleRequest.didReceive(response: simpleResponse)
                } else {
                    simpleRequest.didReceive(error: .invalidResponse)
                }
            }
        }.resume()
    }

    private func buildURLRequest(from simpleRequest: SimpleRequest) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(simpleRequest.path))
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
    public func get(_ path: String, _ requestBuilder: SimpleRequestBuilder) {
        execute(request: requestBuilder(SimpleNetworking.get(path)))
    }

    public class func get(_ path: String) -> SimpleRequest {
        return SimpleRequest(path: path, httpMethod: .get)
    }
}

extension SimpleNetworking: CustomStringConvertible {
    public var description: String {
        return "SimpleNetworking<baseURL: \"\(baseURL)\">"
    }
}
