//
//  Listen_on_MacApp.swift
//  Listen on Mac
//
//  Created by Bastian Inuk Christensen on 03/07/2020.
//  Copyright © 2020 Bastian Inuk Christensen. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct ListenInPlace: App {
    @Environment(\.scenePhase)
    var scenePhase
    
    let player: Player
    init() {
        player = Player.shared
    }
        
        
    var body: some Scene {
        WindowGroup() {
            ContentView()
                .accentColor(.orange)
                .environmentObject(player)
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
                case .active:
                    self.player.addPeriodicTimeObserver()
                    break
                case .inactive, .background:
                    self.player.removePeriodicTimeObserver()
                @unknown default:
                    fatalError("Unknown case")
            }
        }
    }
}
