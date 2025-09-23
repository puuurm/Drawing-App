//
//  DataRequest.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/23/25.
//

import Foundation

class DataRequest {
    let convertible: URLRequestConvertible
    var data: Data?
    
    init(convertible: URLRequestConvertible, data: Data? = nil) {
        self.convertible = convertible
        self.data = data
    }
}
