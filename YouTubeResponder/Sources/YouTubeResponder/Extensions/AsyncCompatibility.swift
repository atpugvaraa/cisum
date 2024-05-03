//
//  AsyncCompatibility.swift
//
//
//  Created by Zain Wu on 2024/4/29.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
extension URLSession {
    
    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            dataTask(with: url) { data, response, error in
                guard let data = data, let response = response else {
                    let error = error ?? URLError(.unknown)
                    return continuation.resume(throwing: error)
                }
                
                continuation.resume(returning: (data, response))
            }
            .resume()
        }
    }
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            dataTask(with: request) { data, response, error in
                guard let data = data, let response = response else {
                    let error = error ?? URLError(.unknown)
                    return continuation.resume(throwing: error)
                }

                continuation.resume(returning: (data, response))
            }
            .resume()
        }
    }
    
}
