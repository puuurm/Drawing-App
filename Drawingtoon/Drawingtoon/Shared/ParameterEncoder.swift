//
//  ParameterEncoder.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/23/25.
//

import Foundation

protocol ParameterEncoder {
    func encode<Parameters: Encodable>(_ parameters: Parameters, into request: URLRequest) throws -> URLRequest
}
