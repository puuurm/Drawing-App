//
//  NetworkManager.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/22/25.
//

import Foundation

public final class NetworkManager {
    
    public static let `default` = NetworkManager()
    
    @discardableResult
    public func requestRaw(
        url: String,
        method: HTTPMethod = .GET,
        parameters: [String: String]? = nil,
        body: Data? = nil,
        headers: [String: String]? = nil
    ) async throws -> RawResponse {
        let req = try buildRequestOrThrow(
            url: url,
            method: method,
            parameters: parameters,
            body: body,
            headers: headers
        )
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        try handleHTTPStatusCode(http.statusCode, data: data)
        return .init(request: req, response: http, data: data)
    }
    
    public func request<T: Decodable>(
        url: String,
        method: HTTPMethod = .GET,
        parameters: [String: String]? = nil,
        body: Data? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        let raw = try await requestRaw(
            url: url,
            method: method,
            parameters: parameters,
            body: body,
            headers: headers
        )
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: raw.data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    public func requestJSON(
        url: String,
        method: HTTPMethod = .GET,
        parameters: [String: String]? = nil,
        body: Data? = nil,
        headers: [String: String]? = nil
    ) async throws -> [String: Any] {
        let raw = try await requestRaw(
            url: url, method: method,
            parameters: parameters, body: body, headers: headers
        )
        do {
            guard let json = try JSONSerialization.jsonObject(with: raw.data) as? [String: Any] else {
                throw NetworkError.decodingError(
                    NSError(domain: "NetworkManager",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "JSON이 Dictionary 형태가 아닙니다."])
                )
            }
            return json
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    public func requestString(
        url: String,
        method: HTTPMethod = .GET,
        parameters: [String: String]? = nil,
        body: Data? = nil,
        headers: [String: String]? = nil,
        encoding: String.Encoding = .utf8
    ) async throws -> String {
        let raw = try await requestRaw(
            url: url, method: method,
            parameters: parameters, body: body, headers: headers
        )
        guard let string = String(data: raw.data, encoding: encoding) else {
            let err = NSError(domain: "NetworkManager", code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "문자열 변환에 실패했습니다."])
            throw NetworkError.decodingError(err)
        }
        return string
    }
        
    private func buildRequestOrThrow(
        url: String,
        method: HTTPMethod,
        parameters: [String: String]?,
        body: Data?,
        headers: [String: String]?
    ) throws -> URLRequest {
        guard var components = URLComponents(string: url) else {
            throw NetworkError.invalidURL
        }
        
        if let parameters, !parameters.isEmpty {
            components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let finalURL = components.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return request
    }
    
    private func handleHTTPStatusCode(_ statusCode: Int, data: Data) throws {
        let message = String(data: data, encoding: .utf8)
        switch statusCode {
        case 100..<200: break
        case 200..<300: break
        case 300..<400:
            throw NetworkError.redirectionError(statusCode, message)
        case 400..<500:
            throw NetworkError.clientError(statusCode, message)
        case 500..<600:
            throw NetworkError.serverError(statusCode, message)
        default:
            throw NetworkError.unknownHTTPError(statusCode, message)
        }
    }
}
