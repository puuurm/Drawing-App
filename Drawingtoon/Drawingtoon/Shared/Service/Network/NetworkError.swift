//
//  NetworkError.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/25/25.
//

import Foundation

public enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError(Error)
    case informationalError(Int, String?)    // 100-199
    case redirectionError(Int, String?)      // 300-399
    case clientError(Int, String?)           // 400-499
    case serverError(Int, String?)           // 500-599
    case unknownHTTPError(Int, String?)      // 기타
    
    var localizedDescription: String {
        switch self {
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
            return "클라이언트 오류 (\(code)): \(message ?? getClientErrorMessage(code))"
        case .serverError(let code, let message):
            return "서버 오류 (\(code)): \(message ?? getServerErrorMessage(code))"
        case .unknownHTTPError(let code, let message):
            return "알 수 없는 HTTP 오류 (\(code)): \(message ?? "알 수 없는 오류")"
        }
    }
    
    private func getClientErrorMessage(_ code: Int) -> String {
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
    
    private func getServerErrorMessage(_ code: Int) -> String {
        switch code {
        case 500: return "내부 서버 오류"
        case 502: return "잘못된 게이트웨이"
        case 503: return "서비스를 사용할 수 없습니다"
        case 504: return "게이트웨이 시간 초과"
        default:  return "서버 오류"
        }
    }
}
