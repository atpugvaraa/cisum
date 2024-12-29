//
//  ProfilePage.swift
//  cisum
//
//  Created by Aarav Gupta on 29/12/24.
//

import SwiftUI

struct ProfilePage: View {
    @Binding var profilePath: NavigationPath
    
    var body: some View {
        NavigationStack(path: $profilePath) {
            Text("Hello, Profile!")
        }
    }
}
