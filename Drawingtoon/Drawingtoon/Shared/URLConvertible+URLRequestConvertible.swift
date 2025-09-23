//
//  URLConvertible+URLRequestConvertible.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/23/25.
//

import Foundation

protocol URLConvertible {
    func asURL() throws -> URL
}

extension String: URLConvertible {
    func asURL() throws -> URL {
        guard let url = URL(string: self) else { throw NetworkError.invalidURL }
        return url
    }
}

extension URL: URLConvertible {
    public func asURL() throws -> URL { self }
}

protocol URLRequestConvertible {
    func asURLRequest() throws -> URLRequest
}

extension URLRequest: URLRequestConvertible {
    func asURLRequest() throws -> URLRequest { self }
}

extension URLRequest {
    init(url: URLConvertible, method: HTTPMethod, headers: [String: String]? = nil) throws {
        let url = try url.asURL()
        self.init(url: url)
        httpMethod = method.rawValue
        allHTTPHeaderFields = headers
    }
}
