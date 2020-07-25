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
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup() {
            ContentView()
                .accentColor(.orange)
                .environmentObject(Player.shared)
                .environment(\.managedObjectContext, appDelegate.persistentContainer.viewContext)
        }
    }
}
