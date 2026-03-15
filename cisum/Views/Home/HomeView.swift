//
//  HomeView.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI
import YouTubeSDK

struct HomeView: View {
    @Environment(\.youtube) private var youtube
    
    @State private var showSheet: Bool = false
    
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                ForEach(1...50, id: \.self) { _ in
                    Rectangle()
                        .fill(.fill.tertiary)
                        .frame(height: 50)
                }
            }
            .padding(15)
        }
        .safeAreaPadding(.top, 140)
        .overlay(content: {
            Button("Login") {
                showSheet = true
            }
        })
        .overlay {
            ZStack {
                VStack(alignment: .leading) {
                    Text("Welcome back,")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Aarav Gupta")
                        .font(.title)
                        .fontWeight(.semibold)
                }
                .padding(.top, 22)
                .padding(.leading)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                
                ProfileButton()
            }
            .padding(.top, 48)
        }
        .sheet(isPresented: $showSheet) {
            GoogleLoginView { cookies in
                YouTubeOAuthClient.saveCookies(cookies)
                
                // Update central YouTube manager with new cookies so all clients refresh
                youtube.cookies = cookies
                
                showSheet = false
            }
        }
        .enableInjection()
    }
}
