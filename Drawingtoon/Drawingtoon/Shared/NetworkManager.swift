//
//  NetworkManager.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/22/25.
//

import Foundation

public let NT = NetworkManager.default

public final class NetworkManager {
    
    static let `default` = NetworkManager()
    
    public func request(
        _ convertible: URLConvertible,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: [String: String]? = nil
    ) -> DataRequest {
        let convertible = RequestConvertible(
            url: convertible,
            method: method,
            parameters: parameters,
            encoding: encoding,
            headers: headers
        )
        return DataRequest(convertible: convertible)
    }
    
    struct RequestConvertible: URLRequestConvertible {
        let url: any URLConvertible
        let method: HTTPMethod
        let parameters: Parameters?
        let encoding: any ParameterEncoding
        let headers: [String: String]?

        func asURLRequest() throws -> URLRequest {
            var request = try URLRequest(url: url, method: method, headers: headers)
            return try encoding.encode(request, with: parameters)
        }
    }
    
}

public enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError(Error)
    case informationalError(Int, String?)
    case redirectionError(Int, String?)
    case clientError(Int, String?)
    case serverError(Int, String?)
    case unknownHTTPError(Int, String?)
    case parameterEncodingFailed
}
