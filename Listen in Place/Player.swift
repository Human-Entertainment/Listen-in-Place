//
//  Player.swift
//  Listen in Place
//
//  Created by Bastian Inuk Christensen on 23/05/2020.
//  Copyright © 2020 Bastian Inuk Christensen. All rights reserved.
//

import Foundation
import AVFoundation

enum PlayerEnum {
    case none
    case AVPlayer(AVPlayer)
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
    private var _avPlayer: AVPlayer?
    @Published var progress: Float = 0.0
    @Published var isPlaying = false
    private var url: URL? = nil
    private var audioQueue = DispatchQueue.init(label: "audio")
    
    var queue: [Song] = []
    
    var song: PlayerEnum {
        set(song) {
            player = song
            
            switch song {
            case .AVPlayer(let player):
                self.url = (player.currentItem?.asset as? AVURLAsset)?.url
            default:
                break
            }
            queue.append(Song(title: "Test", artist: "Test"))
            play()
        }
        
        get {
            player
        }
    }
    
    init() {
        player = .none
    }
    
    func toggle() {
        if isPlaying {
            pause()
            isPlaying = false
        } else {
            play()
            isPlaying = true
        }
    }
    
    func play(_ song: URL) {
        
    }
    
    func play() {
        switch player {
        case .AVPlayer(let player):
            player.play()
            player.addPeriodicTimeObserver(forInterval: .init(seconds: 0.5, preferredTimescale: CMTimeScale(kCMTimeMaxTimescale)),
                                           queue: nil,
                                           using: { time in
                                            let seconds = time.seconds
                                            let duration = player.currentItem?.duration.seconds ?? 0
                                            let percent = seconds / duration
                                            self.progress = Float( percent )
                                            print ( percent )
            })
        default:
            break
        }
        isPlaying = true
    }
    
    
    
    func pause() {
        switch player {
        case .AVPlayer(let player):
            player.pause()
        default:
            break
        }
    }
}
