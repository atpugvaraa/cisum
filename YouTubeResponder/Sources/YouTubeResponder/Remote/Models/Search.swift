//
//  Search.swift
//
//
//  Created by Zain Wu on 2024/4/29.
//

import Foundation


public struct SearchResults: Codable {
    public var items = [SearchResult]()
}

public struct SearchResult: Codable, Identifiable {
    public var id: String
    public var originalID: originalID
    public var snippet: Snippet
    
    enum CodingKeys: String, CodingKey {
        case id = "etag"
        case originalID = "id"
        case snippet
    }
    
    public struct originalID: Codable {
        var videoId: String
    }

    public struct Snippet: Codable {
        var title: String
        var thumbnails: Thumbnails
        var channelTitle: String
    }

    public struct Thumbnails: Codable {
        var `default`: Thumbnail
        var medium: Thumbnail
        var high: Thumbnail
    }

    public struct Thumbnail: Codable {
        var url: String
    }
}

extension SearchResultsRoot {
    func toResult() throws -> SearchResults {
        let resultsRaw = self.contents.sectionListRenderer.contents.compactMap { content -> SearchResultsRoot.Contents.SectionSectionRenderer? in
            
            switch content {
            case .videos(let sectionSectionRenderer):
                return sectionSectionRenderer
            case .continuation(_):
                return nil
            }
        }.first
        guard let resultsRaw else {
            throw NSError(domain: "The result contains no content", code: 0)
        }
        
        let results = resultsRaw.itemSectionRenderer.contents.compactMap({ contentType -> SearchResultsRoot.Contents.SectionListVideoWithContextRendererContent? in
            switch contentType {
            case .video(let sectionListVideoWithContextRendererContent):
                return sectionListVideoWithContextRendererContent
            case .radio(_):
                return nil
            case nil:
                return nil
            }
        })
        
        let videosResults = results.compactMap { result -> SearchResult? in
            if let videoTitle = result.videoWithContextRenderer.headline.runs.first?.text {
                let videoId = result.videoWithContextRenderer.videoId
                return .init(id: videoId,
                             originalID: .init(videoId: videoId)
                             , snippet: .init(title: videoTitle,
                                              thumbnails: .init(default: .init(url: ""), medium: .init(url: ""), high: .init(url: "")), channelTitle: ""))
            }
            return nil
        }
        
        return .init(items: videosResults)
    }
}


// MARK: - Root
struct SearchResultsRoot: Codable {
    let contents: Contents
    
    // MARK: - Contents
    struct Contents: Codable {
        let sectionListRenderer: SectionListRendererMainContent
        
        
        struct SectionListRendererMainContent: Codable {
            let contents: [SectionListRendererMainType]
            
            
            enum SectionListRendererMainType: Codable {
                case videos(SectionSectionRenderer)
                case continuation(String)
                init(from decoder: any Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let videos = try? container.decode(SectionSectionRenderer.self) {
                        self = .videos(videos)
                    } else {
                        self = .continuation("Placholder")
                    }
                }
                
            }
        }
        
        struct SectionSectionRenderer: Codable {
            let itemSectionRenderer: SectionListRenderer
        }
        
        // MARK: - SectionListRenderer
        struct SectionListRenderer: Codable {
            let contents: [SectionListRendererContentType?]

            enum CodingKeys: String, CodingKey {
                case contents
            }
        }
        
        enum SectionListRendererContentType: Codable {
            case video(SectionListVideoWithContextRendererContent)
            case radio(String)
            
            init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let video = try? container.decode(SectionListVideoWithContextRendererContent.self) {
                    self = .video(video)
                } else {
                    self = .radio("Placholder")
                }
            }
        }
        
        
        struct SectionListVideoWithContextRendererContent: Codable {
            let videoWithContextRenderer: SectionListRendererContent
        }
        
        struct SectionListRendererContent: Codable {
            let headline: SectionListRendererContentHeadline
            let videoId: String
            
            
            struct SectionListRendererContentHeadline: Codable {
                let runs: [SectionListRendererContentHeadlineRuns]
                
                struct SectionListRendererContentHeadlineRuns: Codable {
                    let text: String
                }
            }
        }

    }
    
}

// MARK: - Root
struct SearchRequetsBody: Codable {
    let context: Context
    let query, params: String
    
    // MARK: - Context
    struct Context: Codable {
        let client: Client
        let user: User
        let request: Request
        let clickTracking: ClickTracking
        let adSignalsInfo: AdSignalsInfo
        
        // MARK: - Client
        struct Client: Codable {
            let hl, gl, deviceMake, deviceModel: String
            let userAgent, clientName, clientVersion, osName: String
            let osVersion, playerType: String
            let screenPixelDensity: Int
            let platform, clientFormFactor: String
            let screenDensityFloat: Int
            let userInterfaceTheme, timeZone, browserName, browserVersion: String
            let acceptHeader, deviceExperimentID: String
            let screenWidthPoints, screenHeightPoints, utcOffsetMinutes: Int
            let memoryTotalKbytes: String
            let mainAppWebInfo: MainAppWebInfo

            enum CodingKeys: String, CodingKey {
                case hl, gl, deviceMake, deviceModel, userAgent, clientName, clientVersion, osName, osVersion, playerType, screenPixelDensity, platform, clientFormFactor, screenDensityFloat, userInterfaceTheme, timeZone, browserName, browserVersion, acceptHeader
                case deviceExperimentID
                case screenWidthPoints, screenHeightPoints, utcOffsetMinutes, memoryTotalKbytes, mainAppWebInfo
            }
        }
        
        
        
        // MARK: - MainAppWebInfo
        struct MainAppWebInfo: Codable {
            let webDisplayMode: String
            let isWebNativeShareAvailable: Bool
        }
        
        
        // MARK: - AdSignalsInfo
        struct AdSignalsInfo: Codable {
            let params: [Param]
        }
        
        // MARK: - Param
        struct Param: Codable {
            let key, value: String
        }

        // MARK: - ClickTracking
        struct ClickTracking: Codable {
            let clickTrackingParams: String
        }
        
        // MARK: - Request
        struct Request: Codable {
            let useSSL: Bool
        }
        
        
        // MARK: - User
        struct User: Codable {
            let lockedSafetyMode: Bool
        }
    }
}


extension SearchRequetsBody {
    init(queryKey: String) {
        self.init(context: Context(client: Context.Client(hl: "zh-CN",
                                                          gl: "SG",
                                                          deviceMake: "Google",
                                                          deviceModel: "Nexus 5",
                                                          userAgent: "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36 Edg/124.0.0.0,gzip(gfe)",
                                                          clientName: "MWEB",
                                                          clientVersion: "2.20240425.07.00",
                                                          osName: "Android",
                                                          osVersion: "6.0",
                                                          playerType: "UNIPLAYER",
                                                          screenPixelDensity: 2,
                                                          platform: "MOBILE",
                                                          clientFormFactor: "SMALL_FORM_FACTOR",
                                                          screenDensityFloat: 2,
                                                          userInterfaceTheme: "USER_INTERFACE_THEME_DARK",
                                                          timeZone: "Asia/Shanghai",
                                                          browserName: "Edge Chromium",
                                                          browserVersion: "124.0.0.0",
                                                          acceptHeader: "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
                                                          deviceExperimentID: "ChxOek0yTWpZM05qWTBORE0zTVRRd016RTFNZz09EOb2tbEGGOb2tbEG",
                                                          screenWidthPoints: 400,
                                                          screenHeightPoints: 650,
                                                          utcOffsetMinutes: 480,
                                                          memoryTotalKbytes: "8000000",
                                                          mainAppWebInfo: Context.MainAppWebInfo(webDisplayMode: "WEB_DISPLAY_MODE_BROWSER", isWebNativeShareAvailable: false)),
                                   user: Context.User(lockedSafetyMode: false),
                                   request: Context.Request(useSSL: true),
                                   clickTracking: Context.ClickTracking(clickTrackingParams: "CAEQwbIBIhMI65PSibjjhQMVSZJLBR0W8QgM"),
                                   adSignalsInfo: Context.AdSignalsInfo(params: [])), query: queryKey, params: "mAEA")
    }
}
