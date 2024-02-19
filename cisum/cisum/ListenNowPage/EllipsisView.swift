//
//  EllipsisView.swift
//  cisum
//
//  Created by Aarav Gupta on 19/02/24.
//

import SwiftUI

struct EllipsisView: View {
  var body: some View {
    Menu {
      Button {
      } label: {
        Label("Repeat", systemImage: "repeat")
      }
      Button {
      } label: {
        Label("Shuffle", systemImage: "shuffle")
      }
      Button {
      } label: {
        Label("Add to Playlist", systemImage: "plus")
      }
    } label: {
      Label("", systemImage: "ellipsis")
    }
  }
}

#Preview {
    EllipsisView()
}
