//
//  DataRequest.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/23/25.
//

import Foundation

class DataRequest {
    var requests: [URLRequest] = []
    let convertible: URLRequestConvertible
    var data: Data?

    init(convertible: URLRequestConvertible, data: Data? = nil) {
        self.convertible = convertible
        self.data = data
    }
    
    public func response(queue: DispatchQueue = .main, completionHandler: @escaping @Sendable (Data?) -> Void) async throws -> Self {
        do {
            guard let request = self.requests.last else { fatalError() }
            let (data, response) = try await URLSession.shared.data(for: request)
            completionHandler(data)
        } catch {
            throw error
        }
        return self
    }
}
