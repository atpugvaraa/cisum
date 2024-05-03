//
//  RemoteStream.swift
//
//
//  Created by Zain Wu on 2024/4/29.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct RemoteStream: Decodable {
    let url: URL
    let itag: Int
    let ext: String
    
    let videoCodec: String?
    let audioCodec: String?
    
    let averageBitrate: Int?
    let audioBitrate: Int?
    let videoBitrate: Int?
    let filesize: Int?
}
