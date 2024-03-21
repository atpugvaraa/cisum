//
//  Functions.swift
//  cisum
//
//  Created by Aarav Gupta on 19/03/24.
//

import SwiftUI

//MARK: FLoating Player
@ViewBuilder
func FloatingPlayer() -> some View {
  @State var expandPlayer: Bool = false
  @Namespace var animation
  ZStack {
    Rectangle()
      .fill(.ultraThickMaterial)
      .overlay {
        //Music Info
        MusicInfo(expandPlayer: $expandPlayer, animation: animation)
      }
  }
  .frame(height: 70)
  //MARK: Separator Line
  .overlay(alignment: .bottom, content: {
    Rectangle()
      .fill(.gray.opacity(0.3))
      .frame(height: 1)
//      .offset(y: -5)
  })
  .offset(y: -49)
}

@ViewBuilder
func Tabs(_ title: String, _ icon: String) -> some View {
  Text(title)
    .tabItem {
      Image(systemName: icon)
      Text(title)
    }
  //Changing Tab Background Color
    .toolbarBackground(.visible, for: .tabBar)
    .toolbarBackground(.ultraThinMaterial, for: .tabBar)
}
