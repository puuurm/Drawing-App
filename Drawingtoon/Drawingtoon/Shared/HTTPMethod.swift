//
//  HTTPMethod.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/23/25.
//

import Foundation

public struct HTTPMethod: RawRepresentable, Hashable {
    
    public static let delete = HTTPMethod(rawValue: "DELETE")
    
    public static let get = HTTPMethod(rawValue: "GET")
    
    public static let head = HTTPMethod(rawValue: "HEAD")
    
    public static let post = HTTPMethod(rawValue: "POST")
    
    public static let put = HTTPMethod(rawValue: "PUT")
    
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct Endpoint {
    enum Scheme: String {
        case http, https

        var port: Int {
            switch self {
            case .http: 80
            case .https: 443
            }
        }
    }
    
    enum Host: String {
        case localhost = "127.0.0.1"
        
        func port(for scheme: Scheme) -> Int {
            switch self {
            case .localhost: 8080
            }
        }
    }
    
    enum Path {
        case method(HTTPMethod)
        
        var string: String {
            switch self {
            case let .method(method):
                "/\(method.rawValue.lowercased())"
            }
        }
        
    }
    var scheme = Scheme.http
    var port: Int { host.port(for: scheme) }
    var host = Host.localhost
    var path = Path.method(.get)
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    
    public static var get: Endpoint { method(.get) }
    
    static func method(_ method: HTTPMethod) -> Endpoint {
        Endpoint(path: .method(method), method: method)
    }
}

extension Endpoint: URLConvertible {
    public var url: URL { try! asURL() }

    public func asURL() throws -> URL {
        var components = URLComponents()
        components.scheme = scheme.rawValue
        components.port = port
        components.host = host.rawValue
        components.path = path.string

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        return try components.asURL()
    }
}

extension URLComponents: URLConvertible {
    public func asURL() throws -> URL {
        guard let url else { throw NetworkError.invalidURL }
        return url
    }
}

extension URLRequest {
    var method: HTTPMethod? {
        get { httpMethod.map(HTTPMethod.init) }
        set { httpMethod = newValue?.rawValue }
    }
}
