//
//  NetworkError.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/23/25.
//

import Foundation

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError(Error)
    case informationalError(Int, String?)
    case redirectionError(Int, String?)
    case clientError(Int, String?)
    case serverError(Int, String?)
    case unknownHTTPError(Int, String?)
}
