//
//  User Search.swift
//  cisum
//
//  Created by Aarav Gupta on 05/05/24.
//

import SwiftUI

struct UserSearch: View {
    @State private var searchUser = ""
    @Binding var isUserSearchEnabled: Bool
    let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706)
    @StateObject var userSearchViewModel = UserSearchViewModel()
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack {
                    ForEach(userSearchViewModel.users) { user in
                        NavigationLink(value: user) {
                            VStack {
                                UserCell(user: user)
                                
                                Divider()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationDestination(for: User.self, destination: { user in
                Profile(user: user)
            })
            .navigationBarLargeTitleItems(visible: true, trailingItems: {
                Toggle("Search", isOn: $isUserSearchEnabled)
                    .padding(.trailing)
                    .toggleStyle(.switch)
                    .tint(AccentColor)
            })
            .navigationTitle("User Search")
            .searchable(text: $searchUser, prompt: "Search for a User")
        }
    }
}

#Preview {
    UserSearch(isUserSearchEnabled: .constant(true))
}
