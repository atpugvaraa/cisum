//
//  QueueView.swift
//  cisum
//
//  Created by Aarav Gupta on 19/02/24.
//
import SwiftUI

struct Song: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
}

struct UpNextView: View {
    @State private var songs: [Song] = [
        Song(title: "Song 1", artist: "Artist 1"),
        Song(title: "Song 2", artist: "Artist 2"),
        Song(title: "Song 3", artist: "Artist 3")
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(songs) { song in
                    SongRow(song: song)
                }
                .onDelete(perform: delete)
                .onMove(perform: move)
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Up Next")
            .navigationBarItems(trailing: EditButton())
        }
    }
    
    func delete(at offsets: IndexSet) {
        songs.remove(atOffsets: offsets)
    }
    
    func move(from source: IndexSet, to destination: Int) {
        songs.move(fromOffsets: source, toOffset: destination)
    }
}

struct SongRow: View {
    let song: Song
    
    var body: some View {
        HStack {
            Image(systemName: "music.note")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .foregroundColor(Color(red: 155/255, green: 155/255, blue: 159/255))
                .padding(.trailing, 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.primary)
                
                Text(song.artist)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "ellipsis")
                .foregroundColor(Color(red: 155/255, green: 155/255, blue: 159/255))
        }
        .padding(.vertical, 8)
        .padding(.leading, 16)
    }
}

struct UpNextView_Previews: PreviewProvider {
    static var previews: some View {
        UpNextView()
    }
}
