//
//  Login Signup.swift
//  cisum
//
//  Created by Aarav Gupta on 09/04/24.
//

import SwiftUI
import Firebase
import FirebaseStorage

struct LoginSignup: View {
  @State var errorMessage: String = ""
  @State var showError: Bool = false
  let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.3)
  @State private var activeTab: loginorsignup = .signup
  @State var email = ""
  @State var password = ""
  @State var showImagePicker = false
  @State var image: UIImage?

  var body: some View {
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
          //Profile Image Button
          if activeTab == .signup {
            Button {
              showImagePicker.toggle()
            } label: {
              VStack {
                if let image = self.image {
                  Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 84)
                    .clipShape(Circle())
                } else {
                  Image(systemName: "person.crop.circle")
                    .font(.system(size: 84))
                    .foregroundColor(.primary)
                }
              }
            }
            .onTapGesture {
              UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
        } else if activeTab == .login {
          Login(email: $email, password: $password)
        }
      }
    }
    .scrollDisabled(true)
    .padding()
    .fullScreenCover(isPresented: $showImagePicker, onDismiss: nil) {
      ImagePicker(image: $image)
    }
  }
}

// Signup View
struct Signup: View {
  @State private var activeTab: loginorsignup = .signup
  let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.3)
  @Binding var email: String
  @Binding var password: String
  @State var image: UIImage?

  var body: some View {
    VStack {
      Button {
        signup()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
      } label: {
        HStack {
          Text("Sign up")
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .padding(.vertical, 10)
        }
        .frame(width: 120)
        .background(accentColor)
      }
      .clipShape(RoundedRectangle(cornerRadius: 100))
    }
  }

  private func signup() {
    if activeTab == .signup {
      FirebaseManager.shared.auth.createUser(withEmail: email, password: password) {result, error in
        if let error = error {
          Toast.shared.present(title: "Failed to create user: \(error)", isUserInteractionEnabled: true, timing: .medium)
          return
        }
        Toast.shared.present(title: "Success! User Created: \(result?.user.uid ?? "")", isUserInteractionEnabled: true, timing: .medium)

        self.persistImage()

        Toast.shared.present(title: "Failed to save image: \(String(describing: error))", isUserInteractionEnabled: true, timing: .medium)
      }
    }
  }

  private func persistImage() {
    //    let filename = UUID().uuidString
    guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {return}
    let ref = FirebaseManager.shared.storage.reference(withPath: uid)
    guard let imageData = self.image?.jpegData(compressionQuality: 0.5) else {return}
    ref.putData(imageData, metadata: nil) { metadata, error in
      if let error = error {
        Toast.shared.present(title: "Failed to save image: \(error)", isUserInteractionEnabled: true, timing: .medium)
        return
      }

      ref.downloadURL {url, error in
        if let error = error {
          Toast.shared.present(title: "Failed to retrieve image: \(error)", isUserInteractionEnabled: true, timing: .medium)
          return
        }

        Toast.shared.present(title: "Saved image and url! \(url?.absoluteString ?? "")", isUserInteractionEnabled: true, timing: .medium)
      }
    }
  }
}

// Login View
struct Login: View {
  @State private var activeTab: loginorsignup = .login
  let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.3)
  @Binding var email: String
  @Binding var password: String

  var body: some View {
    VStack {
      Button {
        login()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
      } label: {
        HStack {
          Text("Login")
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .padding(.vertical, 10)
        }
        .frame(width: 120)
        .background(accentColor)
      }
      .clipShape(RoundedRectangle(cornerRadius: 100))
    }
  }

  private func login() {
    if activeTab == .login {
      FirebaseManager.shared.auth.signIn(withEmail: email, password: password) {result, error in
        if let error = error {
          Toast.shared.present(title: "Failed to login user: \(error)", isUserInteractionEnabled: true, timing: .medium)
          return
        }
        Toast.shared.present(title:"Success! Logged in as: \(result?.user.uid ?? "")", isUserInteractionEnabled: true, timing: .medium)
      }
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
