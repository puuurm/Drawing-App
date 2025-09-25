//
//  DataRequest.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/23/25.
//

import Foundation

public class DataRequest {
    var requests: [URLRequest] = []
    let convertible: URLRequestConvertible
    var data: Data?

    init(convertible: URLRequestConvertible, data: Data? = nil) {
        self.convertible = convertible
        self.data = data
    }
    
    public func response(
        queue: DispatchQueue = .main,
        completionHandler: @escaping (Data) -> Void
    ) -> Self {
        do {
            let request = try convertible.asURLRequest()
            self.requests.append(request)
            
            let task = URLSession.shared.dataTask(with: request) { data, _, error in
                let payload: Data
                if let d = data {
                    self.data = d
                    payload = d
                } else {
                    payload = Data()
                }
                
                queue.async {
                    completionHandler(payload)
                }
            }
            task.resume()
        } catch {
            let payload = Data()
            queue.async { completionHandler(payload) }
        }

        return self
    }
}

public struct DataResponse<Success, Failure: Error> {
    let request: URLRequest?
    let response: HTTPURLResponse?
    let data: Data?
    var error: Error?
}
