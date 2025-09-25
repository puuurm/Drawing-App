//
//  NetworkManager.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/22/25.
//

import Foundation

public let NT = NetworkManager.default

public final class NetworkManager {
    
    public static let `default` = NetworkManager()
        
    public enum NetworkError: Error {
        case invalidURL
        case noData
        case decodingError(Error)
        case informationalError(Int, String?)    // 100-199
        case redirectionError(Int, String?)      // 300-399
        case clientError(Int, String?)           // 400-499
        case serverError(Int, String?)           // 500-599
        case unknownHTTPError(Int, String?)      // 기타
    }
    
    public static func localizedDescription(for error: NetworkError) -> String {
        switch error {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .noData:
            return "데이터가 없습니다."
        case .decodingError(let error):
            return "데이터 디코딩에 실패했습니다: \(error.localizedDescription)"
        case .informationalError(let code, let message):
            return "정보 응답 (\(code)): \(message ?? "알 수 없는 정보 응답")"
        case .redirectionError(let code, let message):
            return "리다이렉션 오류 (\(code)): \(message ?? "리다이렉션이 필요합니다")"
        case .clientError(let code, let message):
            return "클라이언트 오류 (\(code)): \(message ?? Self.getClientErrorMessage(code))"
        case .serverError(let code, let message):
            return "서버 오류 (\(code)): \(message ?? Self.getServerErrorMessage(code))"
        case .unknownHTTPError(let code, let message):
            return "알 수 없는 HTTP 오류 (\(code)): \(message ?? "알 수 없는 오류")"
        }
    }
    
    public static func getStatusCategory(_ statusCode: Int) -> HTTPStatusCategory {
        switch statusCode {
        case 100..<200: return .informational
        case 200..<300: return .success
        case 300..<400: return .redirection
        case 400..<500: return .clientError
        case 500..<600: return .serverError
        default:        return .unknown
        }
    }
    
    private static func getClientErrorMessage(_ code: Int) -> String {
        switch code {
        case 400: return "잘못된 요청"
        case 401: return "인증이 필요합니다"
        case 403: return "접근이 금지되었습니다"
        case 404: return "리소스를 찾을 수 없습니다"
        case 405: return "허용되지 않는 메소드"
        case 408: return "요청 시간 초과"
        case 429: return "너무 많은 요청"
        default:  return "클라이언트 오류"
        }
    }
    
    private static func getServerErrorMessage(_ code: Int) -> String {
        switch code {
        case 500: return "내부 서버 오류"
        case 502: return "잘못된 게이트웨이"
        case 503: return "서비스를 사용할 수 없습니다"
        case 504: return "게이트웨이 시간 초과"
        default:  return "서버 오류"
        }
    }
    
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

public enum HTTPMethod: String {
    case GET, POST, PUT, PATCH, DELETE
}

public enum HTTPStatusCategory: String {
    case informational, success, redirection, clientError, serverError, unknown
}

public struct RawResponse {
    public let request: URLRequest
    public let response: HTTPURLResponse
    public let data: Data
    
    public var text: String? { String(data: data, encoding: .utf8) }
    public var isSuccess: Bool { (200..<300).contains(response.statusCode) }
}
