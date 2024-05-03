//
//  Method.swift
//
//
//  Created by Zain Wu on 2024/4/29.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
extension YouTube {
    
    public enum ExtractionMethod: Hashable {
        case local
        case remote(serverURL: URL)
        
        public static var remote: ExtractionMethod {
            return .remote(serverURL: URL(string: "https://youtubekit-remote.losjet.com")!)
        }
    }
    
}
