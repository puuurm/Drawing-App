//
//  NetworkManager.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/22/25.
//

import Foundation

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

struct HTTPMethod: RawRepresentable {
    
    static let get = HTTPMethod(rawValue: "GET")
    
    static let post = HTTPMethod(rawValue: "POST")
    
    static let put = HTTPMethod(rawValue: "PUT")
    
    static let delete = HTTPMethod(rawValue: "DELETE")

    let rawValue: String
    
    init(rawValue: String) {
        self.rawValue = rawValue
    }
    
}



class DataRequest {
    let convertible: URLRequestConvertible
    var data: Data?
    
    init(convertible: URLRequestConvertible, data: Data? = nil) {
        self.convertible = convertible
        self.data = data
    }
}

extension URLRequest {
    init(url: URLConvertible, method: HTTPMethod, headers: [String: String]? = nil) throws {
        let url = try url.asURL()
        self.init(url: url)
        httpMethod = method.rawValue
        allHTTPHeaderFields = headers
    }
}

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

extension URLComponents: URLConvertible {
    public func asURL() throws -> URL {
        guard let url else { throw NetworkError.invalidURL }

        return url
    }
}

protocol URLRequestConvertible {
    func asURLRequest() throws -> URLRequest
}

extension URLRequest: URLRequestConvertible {
    func asURLRequest() throws -> URLRequest { self }
}



enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError(Error)
    case informationalError(Int, String?)    // 100-199
    case redirectionError(Int, String?)      // 300-399
    case clientError(Int, String?)           // 400-499
    case serverError(Int, String?)           // 500-599
    case unknownHTTPError(Int, String?)      // 기타
}

protocol ParameterEncoder {
    func encode<Parameters: Encodable>(_ parameters: Parameters, into request: URLRequest) throws -> URLRequest
}

protocol ParameterEncoding {
    func encode(_ urlRequest: URLRequestConvertible, with parameters: [String: String]?) throws -> URLRequest
}
