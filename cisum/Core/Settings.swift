//
//  Settings.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Settings: View {
  var body: some View {
    ScrollView {
      CreditsRow(name: "Aarav Gupta", role: "Main Developer", link: URL(string: "https://github.com/atpugvaraa")).foregroundColor(.accentColor)
      CreditsRow(name: "Mattycbtw", role: "Current API Integration", link: URL(string: "https://twitter.com/mattycbtw")).foregroundStyle(.white)
      CreditsRow(name: "Zain", role: "Lyrics", link: URL(string: "https://twitter.com/LaunchMask")).foregroundStyle(.white)
      CreditsRow(name: "Piped API", role: "Music Search", link: URL(string: "https://docs.piped.video/docs/api-documentation/")).foregroundStyle(.white)
    }
    .navigationBarTitleDisplayMode(.large)
    .navigationTitle("Settings")
    .padding(.top)
  }
}

struct CreditsRow: View {
  let name: String
  let role: String
  let link: URL?

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(name)
          .font(.headline)

        Text(role)
          .font(.subheadline)
          .foregroundColor(.gray)
      }

      Spacer()

      if let link = link {
        Button {
          UIApplication.shared.open(link)
        } label: {
          Text("VIEW")
            .font(.headline)
            .bold()
            .foregroundColor(.accentColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
      }
    }
    .padding(.horizontal, 15)
    .padding(.vertical, 8)
  }
}

#Preview {
  Settings()
}
