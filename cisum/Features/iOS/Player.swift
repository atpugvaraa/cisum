//
//  Player.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 11/05/25.
//

import SwiftUI

@Observable
class Player {
    static let shared = Player()

    var currentSong = "Not Playing"
    var isPlaying = false
    var artwork = Image(.notPlaying)
}
