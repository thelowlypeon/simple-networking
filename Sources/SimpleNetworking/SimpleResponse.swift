//
//  SimpleResponse.swift
//  SimpleNetworking
//
//  Created by Peter Compernolle on 8/24/19.
//  Copyright © 2019 Peter Compernolle. All rights reserved.
//

import Foundation

public class SimpleResponse {
    public let httpData: Data?
    public let httpResponse: HTTPURLResponse
    public var httpStatus: Int {
        return httpResponse.statusCode
    }

    public let success: Bool

    public let error: SimpleNetworkingError?

    public let json: Any?
    public let text: String?

    public init?(data httpData: Data?,
                response httpResponse: HTTPURLResponse?) {

        guard let response = httpResponse else { return nil }
        self.httpData = httpData
        self.httpResponse = response

        self.success = (100..<399).contains(response.statusCode) // includes redirects

        if (400..<499).contains(response.statusCode) {
            self.error = .clientError(response.statusCode)
        } else if (500..<599).contains(response.statusCode) {
            self.error = .serverError(response.statusCode)
        } else if !self.success {
            self.error = .invalidResponse
        } else {
            self.error = nil
        }

        if let data = httpData {
            self.text = String(data: data, encoding: .utf8)
            self.json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
        } else {
            self.text = nil
            self.json = nil
        }
    }
}

extension SimpleResponse: CustomStringConvertible {
    public var description: String {
        return "SimpleResponse<httpStatus: \(httpStatus), body: \(String(describing: text))>"
    }
}

// decoding
extension SimpleResponse {
    public func decodeJSON<T: Decodable>(using aDecoder: JSONDecoder? = nil) -> T? {
        guard let data = httpData else { return nil }

        let decoder = aDecoder ?? JSONDecoder()

        return try? decoder.decode(T.self, from: data)
    }
}
