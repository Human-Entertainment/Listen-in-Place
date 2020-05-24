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

struct Song: Hashable {
    let title: String
    let artist: String
}

final class Player: ObservableObject {
    private var player: AVPlayer
    private var url: URL
    @Published var progress: Float = 0.0
    
    init(url: URL) {
        self.player = AVQueuePlayer(url: url)
        self.url = url
    }
    
    func play() {
        self.player.play()
    }
    
    func pause() {
        self.player.pause()
    }
}
