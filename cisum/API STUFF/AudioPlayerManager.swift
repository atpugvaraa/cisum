//
//  AudioPlayerManager.swift
//  cisum
//
//  Created by Aarav Gupta on 31/03/2024.
//

import Foundation
import AVFoundation

class AudioPlayerManager: ObservableObject {
    private var audioPlayer: AVPlayer?
    
    func playAudio(from url: URL) {
        audioPlayer = AVPlayer(url: url)
        audioPlayer?.play()
    }
}
