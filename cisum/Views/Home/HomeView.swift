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
            Color.black
            
            ScrollView {
                Button("Login") {
                    showSheet = true
                }
            }
            .ignoresSafeArea()
            .contentMargins(.top, 140)
        }
        .ignoresSafeArea()
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
            .padding(.top, 200)
        }
        .sheet(isPresented: $showSheet) {
            GoogleLoginView { cookies in
                YouTubeOAuthClient.saveCookies(cookies)
                
                youtube.cookies = cookies
                
                showSheet = false
            }
        }
        .enableInjection()
    }
}
