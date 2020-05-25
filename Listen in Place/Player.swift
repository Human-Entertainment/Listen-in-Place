//
//  Player.swift
//  Listen in Place
//
//  Created by Bastian Inuk Christensen on 23/05/2020.
//  Copyright © 2020 Bastian Inuk Christensen. All rights reserved.
//

import Foundation
import AVFoundation
import Combine

enum PlayerEnum {
    case none
    case AVPlayer(AV)
}

struct Song: Hashable {
    let title: String
    let artist: String
}

struct AV {
    private var player: AVPlayer
    private var url: URL
}

final class Player: ObservableObject {
    var player: PlayerEnum
    @Published var progress: Float = 0.0
    
    init() {
        player = .none
    }
}
