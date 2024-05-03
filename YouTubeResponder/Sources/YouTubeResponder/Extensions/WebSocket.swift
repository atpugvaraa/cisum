//
//  WebSocket.swift
//
//
//  Created by Zain Wu on 2024/4/29.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
extension JSONDecoder {
    
    func decode<T: Decodable>(_ type: T.Type, from message: URLSessionWebSocketTask.Message) throws -> T {
        switch message {
        case .data(let data):
            return try decode(type, from: data)
        case .string(let string):
            return try decode(type, from: string.data(using: .utf8) ?? Data())
        @unknown default:
            fatalError()
        }
    }
    
}

@available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
extension URLSessionWebSocketTask {
    
    func send(_ value: some Encodable, encoder: JSONEncoder = JSONEncoder()) async throws {
        let encoded = try encoder.encode(value)
        try await send(.data(encoded))
    }
    
}
