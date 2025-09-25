//
//  ParameterEncoder.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/23/25.
//

import Foundation

public typealias Parameters = [String: Any]

public protocol ParameterEncoder {
    func encode<Parameters: Encodable>(_ parameters: Parameters, into request: URLRequest) throws -> URLRequest
}

public protocol ParameterEncoding {
    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest
}

public struct URLEncoding: ParameterEncoding {
    
    enum Destination {
        case methodDependent
        
        func encodesParametersInURL(for method: HTTPMethod) -> Bool {
            switch self {
            case .methodDependent: [.get, .head, .delete].contains(method)
            }
        }
    }
    
    public static var `default`: URLEncoding { URLEncoding() }
    
    let destination: Destination
    
    init(destination: Destination = .methodDependent) {
        self.destination = destination
    }
    
    public func encode(_ urlRequest: any URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        
        guard let parameters else { return urlRequest }
        
        if let method = urlRequest.method, destination.encodesParametersInURL(for: method) {
            guard let url = urlRequest.url else {
                throw NetworkError.parameterEncodingFailed
            }
            
            if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false), !parameters.isEmpty {
                let percentEncodedQuery = (urlComponents.percentEncodedQuery.map { $0 + "&" } ?? "") + query(parameters)
                urlComponents.percentEncodedQuery = percentEncodedQuery
                urlRequest.url = urlComponents.url
            }
        }
        
        return urlRequest
    }
    
    func queryComponents(fromKey key: String, value: Any) -> [(String, String)] {
        return []
    }
    
    private func query(_ parameters: [String: Any]) -> String {
        var components: [(String, String)] = []
        for key in parameters.keys.sorted(by: <) {
            let value = parameters[key]!
            components += queryComponents(fromKey: key, value: value)
        }
        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }
}
