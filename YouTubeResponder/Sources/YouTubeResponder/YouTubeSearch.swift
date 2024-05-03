//
//  File.swift
//  
//
//  Created by Zain Wu on 2024/4/29.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public class YouTubeSearch {
    
    public static func results(keyword: String) async throws -> SearchResults {
        let url: String = "https://m.youtube.com/youtubei/v1/search?prettyPrint=false"
        let requestHeaders: [String: String] = ["sec-ch-ua" : """
"Chromium";v="124", "Microsoft Edge";v="124", "Not-A.Brand";v="99"
""",
                                                   "X-Youtube-Bootstrap-Logged-In": "false",
                                                "User-Agent": "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36 Edg/124.0.0.0", "Content-Type": "application/json", "X-Youtube-Client-Name": "2", "X-Youtube-Client-Version": "2.20240425.07.00", "sec-ch-ua-platform": "Android", "Origin": "https://m.youtube.com"]
        guard let url: URL = URL(string: url) else {
            throw NSError(domain: "aaa", code: .zero)
        }
        
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = requestHeaders
        request.httpMethod = "POST"
        let httpBody = SearchRequetsBody.init(queryKey: keyword)
        let httpBodyData = try JSONEncoder().encode(httpBody)
        request.httpBody = httpBodyData
        let task = try await URLSession.shared.asyncData(from: request)
        
        let model = try JSONDecoder().decode(SearchResultsRoot.self, from: task.0)
        
        return try model.toResult()
    }
}
