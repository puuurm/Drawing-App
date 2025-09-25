//
//  RawResponse.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/25/25.
//

import Foundation

public struct RawResponse {
    public let request: URLRequest
    public let response: HTTPURLResponse
    public let data: Data
    public var text: String? { String(data: data, encoding: .utf8) }
    public var isSuccess: Bool { (200..<300).contains(response.statusCode) }
}
