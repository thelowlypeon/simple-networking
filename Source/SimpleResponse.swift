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

    public let json: Dictionary<String, Any>?

    public let text: String?

    public init?(data httpData: Data?,
                response httpResponse: HTTPURLResponse?) {

        guard let response = httpResponse else { return nil }
        self.httpData = httpData
        self.httpResponse = response

        self.success = (100..<399).contains(response.statusCode)

        if (400..<499).contains(response.statusCode) {
            self.error = .clientError(response.statusCode)
        } else if (500..<599).contains(response.statusCode) {
            self.error = .serverError(response.statusCode)
        } else if !self.success {
            self.error = .invalidResponse
        } else {
            self.error = nil
        }

        self.json = httpData?.toDictionary()
        self.text = httpData?.toString()
    }

    internal func validFor(contentType: SimpleRequest.ContentType) -> Bool {
        if httpData == nil { return true }
        switch contentType {
        case .json: return json != nil
        case .text: return text != nil
        }
    }
}

extension SimpleResponse: CustomStringConvertible {
    public var description: String {
        return "SimpleResponse<httpStatus: \(httpStatus), body: \(text ?? "null")>"
    }
}

extension Data {
    public func toDictionary<T, U>() -> Dictionary<T, U>? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: self, options: .mutableContainers) else { return nil }
        return jsonObject as? Dictionary<T, U>
    }

    public func toString() -> String? {
        let str = String(data: self, encoding: .utf8)
        return str != "" ? str : nil
    }
}
