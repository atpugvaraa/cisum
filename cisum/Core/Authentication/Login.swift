//
//  Login.swift
//  cisum
//
//  Created by Aarav Gupta on 03/05/24.
//

import SwiftUI

struct Login: View {
    let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.4)
    @StateObject var loginViewModel = LoginViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Spacer()
            
          Image("Icon")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .padding(.vertical)
            
            VStack(spacing: 10) {
                TextField("Email", text: $loginViewModel.email)
                    .autocapitalization(.none)
                    .font(.subheadline)
                    .padding(12)
                    .background(.gray.opacity(0.3))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                
                SecureField("Password", text: $loginViewModel.password)
                    .autocapitalization(.none)
                    .font(.subheadline)
                    .padding(12)
                    .background(.gray.opacity(0.3))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
            }
                
                Button{
                    Task { try await loginViewModel.login() }
                } label: {
                 Text("Login")
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 352, height: 44)
                        .background(accentColor)
                        .cornerRadius(10)
                        .padding(.top, 3)
                }
            
            NavigationLink {
                Text("Forgot Password?")
            } label: {
                Text("Forgot Password?")
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.vertical)
            }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 3) {
                        Text("Don't have an account?")
                        Text("Sign Up")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .font(.subheadline)
                }
                .padding(.vertical, 16)
        }
    }
}

#Preview {
    Login()
        .preferredColorScheme(.dark)
}
