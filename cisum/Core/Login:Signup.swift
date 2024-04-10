//
//  Login:Signup.swift
//  cisum
//
//  Created by Aarav Gupta on 09/04/24.
//

import SwiftUI

struct LoginSignup: View {
  let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.3)
  @State private var activeTab: loginorsignup = .signup
  @State private var offsetY: CGFloat = 0
  @State var email = ""
  @State var password = ""

  var body: some View {
    NavigationView{
        ScrollView {
          VStack(spacing: 16)  {
            VStack(spacing: 15) {
              LoginOrSignup(tabs: loginorsignup.allCases, activeTab: $activeTab, height: 35, font: .body, activeTint: .primary, inActiveTint: .gray.opacity(0.5)) { size in
                RoundedRectangle(cornerRadius: 30)
                  .fill(accentColor)
                  .frame(height: size.height)
                  .frame(maxHeight: .infinity, alignment: .bottom)
              }
              .padding(.horizontal, 50)
              .toolbarBackground(.hidden, for: .navigationBar)
            }
            .padding(.top)

            VStack {
              if activeTab == .signup {
                Button {

                } label: {
                  Image(systemName: "person.crop.circle")
                    .font(.system(size: 84))
                    .foregroundColor(.primary)
                }
                .padding(.top, 50)
              }

              VStack {
                TextField("Email", text: $email)
                  .keyboardType(.emailAddress)
                  .padding(.vertical)
                SecureField("Password", text: $password)
                  .padding(.vertical)
              }
              .padding(.horizontal)
              .padding(6)
              .autocorrectionDisabled()
              .autocapitalization(.none)
            }

            // Conditionally show different views based on activeTab
            if activeTab == .signup {
              Signup(email: $email, password: $password)
            } else {
              Login(email: $email, password: $password)
            }
          }
        }
        .offset(y: offsetY)
        .gesture(
            DragGesture()
                .onChanged({ _ in
                    offsetY = .zero
                })
        )
        .navigationTitle(activeTab.rawValue)
        .padding()
    }
  }
}

// Signup View
struct Signup: View {
  let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.3)
  @Binding var email: String
  @Binding var password: String

  var body: some View {
    VStack {
      Button {
        // Add action for signup button
      } label: {
        HStack {
          Text("Sign up")
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .padding(.vertical, 10)
        }
        .frame(width: 120)
        .background(accentColor) // Change color as needed
      }
      .clipShape(RoundedRectangle(cornerRadius: 100))

      // Add other signup related UI components here
    }
  }
}

// Login View
struct Login: View {
  let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.3)
  @Binding var email: String
  @Binding var password: String

  var body: some View {
    VStack {
      Button {
        // Add action for login button
      } label: {
        HStack {
          Text("Login")
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .padding(.vertical, 10)
        }
        .frame(width: 120)
        .background(accentColor) // Change color as needed
      }
      .clipShape(RoundedRectangle(cornerRadius: 100))

      // Add other login related UI components here
    }
  }
}

//MARK: Segmented Control
struct LoginOrSignup<Indicator: View>: View {
  var tabs: [loginorsignup]
  @Binding var activeTab: loginorsignup
  var height: CGFloat = 35
  var displayAsText = true
  var font: Font = .title3
  var activeTint: Color
  var inActiveTint: Color
  // Indicator View
  @ViewBuilder var indicatorView: (CGSize) -> Indicator

  @State private var minX: CGFloat = .zero
  @State private var excessTabWidth: CGFloat = .zero

  var body: some View {
    GeometryReader { geometry in
      let containerWidthForEachTab = geometry.size.width / CGFloat(tabs.count)

      HStack(spacing: 0) {
        ForEach(tabs, id: \.rawValue) { tab in
          Text(tab.rawValue)
            .font(font)
            .fontWeight(.semibold)
            .foregroundStyle(activeTab == tab ? activeTint : inActiveTint)
            .animation(.snappy, value: activeTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
              if let index = tabs.firstIndex(of: tab), let activeIndex = tabs.firstIndex(of: activeTab) {
                activeTab = tab

                withAnimation(Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
                  excessTabWidth = containerWidthForEachTab * CGFloat(index - activeIndex)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                  withAnimation(Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
                    minX = containerWidthForEachTab * CGFloat(index)
                    excessTabWidth = 0
                  }
                }
              }
            }
            .background(alignment: .leading) {
              if tabs.first == tab {
                GeometryReader { indicatorGeometry in
                  let size = indicatorGeometry.size

                  indicatorView(size)
                    .frame(width: size.width + (excessTabWidth < 0 ? -excessTabWidth : excessTabWidth), height: size.height)
                    .frame(width: size.width, alignment: excessTabWidth < 0 ? .trailing : .leading)
                    .offset(x: minX)
                }
              }
            }
        }
      }
      .frame(height: height)
    }
  }
}

enum loginorsignup: String, CaseIterable {
  case signup = "Sign up"
  case login = "Login"
}

#Preview {
  LoginSignup()
    .preferredColorScheme(.dark)
}
