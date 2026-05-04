//
//  JSCoreJavaScriptRuntime.swift
//  cisum
//
//  Created by Aarav Gupta on 26/04/26.
//

import Foundation
import JavaScriptCore
import YouTubeSDK

#warning("Will remove Apple Frameworks from SDK later")
/// An Apple-specific implementation of JavaScript execution using JavaScriptCore.
//public final class AppleJSRuntime: YouTubeJavaScriptRuntime, @unchecked Sendable {
//    private let context = JSContext()!
//    
//    public init() {}
//    
//    public func evaluateScript(_ script: String) async throws -> String? {
//        let result = context.evaluateScript(script)
//        return result?.toString()
//    }
//    
//    public func callFunction(_ name: String, withArguments arguments: [Any]) async throws -> String? {
//        guard let function = context.objectForKeyedSubscript(name) else {
//            return nil
//        }
//        
//        let result = function.call(withArguments: arguments)
//        return result?.toString()
//    }
//}
