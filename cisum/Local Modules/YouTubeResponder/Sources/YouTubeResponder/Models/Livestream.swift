//
//  Livestream.swift
//
//
//  Created by Zain Wu on 2024/4/29.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct Livestream {
    
    public enum StreamType {
        case hls
    }
    
    public let url: URL
    public let streamType: StreamType
    
}
