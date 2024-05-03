//
//  Retry.swift
//
//
//  Created by Zain Wu on 2024/4/29.
//

import Foundation

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
extension Task {
    
    fileprivate enum RetryError: Error {
        case emptyMethods
    }

    static func retry<Method>(with methods: [Method], block: (Method) async throws -> Success) async throws -> Success where Failure == Never {
        
        var lastError: any Error = RetryError.emptyMethods
        
        for method in methods {
            do {
                return try await block(method)
            } catch let error {
                lastError = error
            }
        }
        
        throw lastError
    }
    
}
