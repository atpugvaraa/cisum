//
//  Settings.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Settings: View {
    var body: some View {
        CreditsView()
    }
}

struct CreditsView: View {
    var body: some View {
        Section(header: Text("Credits").foregroundColor(.accentColor)) {
            CreditsRow(name: "Aarav Gupta", role: "Main Developer", link: URL(string: "https://github.com/atpugvaraa")).foregroundColor(.accentColor)
            CreditsRow(name: "Mattycbtw", role: "API Integration", link: URL(string: "https://twitter.com/mattycbtw")).foregroundStyle(.white)
            CreditsRow(name: "Zain", role: "Lyrics", link: URL(string: "https://twitter.com/LaunchMask")).foregroundStyle(.white)
            CreditsRow(name: "Piped API", role: "Music Search", link: URL(string: "https://docs.piped.video/docs/api-documentation/")).foregroundStyle(.white)
        }
    }
}

struct CreditsRow: View {
    let name: String
    let role: String
    let link: URL?
    var body: some View {
        Link(destination: link ?? URL(string: "file:///")!) {
            HStack {
                Text(name)
                    .font(.body.bold())
                    .lineLimit(1)
                Spacer()
                Text(role)
                    .opacity(0.7)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    Settings()
}
