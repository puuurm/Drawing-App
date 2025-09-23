//
//  HTTPMethod.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/23/25.
//

import Foundation

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
