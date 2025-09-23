//
//  NetworkManager.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/22/25.
//

import Foundation

let NT = NetworkManager.default

class NetworkManager {
    
    static let `default` = NetworkManager()
    
    func request<Parameters: Encodable>(
        _ convertible: URLConvertible,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoder: ParameterEncoder,
        headers: [String: String]? = nil
    ) -> DataRequest {
        let convertible = RequestEncodableConvertible(
            url: convertible,
            method: method,
            parameters: parameters,
            encoder: encoder,
            headers: headers
        )
        return DataRequest(convertible: convertible)
    }
    
    struct RequestEncodableConvertible<Parameters: Encodable>: URLRequestConvertible {
        let url: any URLConvertible
        let method: HTTPMethod
        let parameters: Parameters?
        let encoder: ParameterEncoder
        let headers: [String: String]?

        func asURLRequest() throws -> URLRequest {
            let request = try URLRequest(url: url, method: method, headers: headers)
            return try parameters.map { try encoder.encode($0, into: request) } ?? request
        }
    }
}
