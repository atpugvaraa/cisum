//
//  Extensions.swift
//  cisum
//
//  Created by Aarav Gupta on 08/04/24.
//

import Foundation
import SwiftUI

class PlayerViewModel: ObservableObject {
    @Published var currentVideoID: String?
    @Published var expandPlayer: Bool = false
    @Published var currentTitle: String? = nil
    @Published var currentArtist: String? = nil
    @Published var currentThumbnailURL: String? = nil
}

extension Double {
    func asTimeString(style: DateComponentsFormatter.UnitsStyle) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = style
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: self) ?? ""
    }
}

extension BinaryFloatingPoint {
    func asTimeString(style: DateComponentsFormatter.UnitsStyle) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = style
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: TimeInterval(self)) ?? "" //formatter.string(from: self) ?? ""
    }
}

extension View {
  var deviceCornerRadius: CGFloat {
    let key = "_displayCornerRadius"
    if let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.screen {
      if let cornerRadius = screen.value(forKey: key) as? CGFloat {
        return cornerRadius
      }

      return 0
    }

    return 0
  }
}
