//
//  Errors.swift
//
//
//  Created by Zain Wu on 2024/4/29.
//

import Foundation

public enum YouTubeResponderError: String, Error {
    case maxRetriesExceeded
    case htmlParseError
    case extractError
    case regexMatchError
    case videoUnavailable
    case videoAgeRestricted
    case liveStreamError
    case videoPrivate
    case recordingUnavailable
    case membersOnly
    case videoRegionBlocked
}

extension YouTubeResponderError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .videoUnavailable:
            return NSLocalizedString("Video unavailable", comment: "")
            
        case .videoAgeRestricted:
            return NSLocalizedString("Video age restricted", comment: "")
            
        case .liveStreamError:
            return NSLocalizedString("Can't extract video from livestream", comment: "")
            
        case .videoPrivate:
            return NSLocalizedString("Video is private", comment: "")
            
        case .membersOnly:
            return NSLocalizedString("Video is members only", comment: "")
            
        default: return nil
        }
    }
    
}
