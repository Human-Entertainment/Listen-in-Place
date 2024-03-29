//
//  Listen_on_MacApp.swift
//  Listen on Mac
//
//  Created by Bastian Inuk Christensen on 03/07/2020.
//  Copyright © 2020 Bastian Inuk Christensen. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import CoreData
import NIO

@main
struct ListenInPlace: App {
    @Environment(\.scenePhase)
    var scenePhase
    
    let player: Player = .init()
        
    var body: some Scene {
        WindowGroup() {
            ContentView()
                .accentColor(.orange)
                .environment(\.managedObjectContext, self.persistentContainer.viewContext)
                .environment(\.threadPool, NIOThreadPool(numberOfThreads: 1))
                .environment(player)
        }
        .modelContainer(for: [Song.self])
        .onChange(of: scenePhase) { (_oldPhase, phase) in
            switch phase {
                case .active:
                    self.player.addPeriodicTimeObserver()
                    break
                case .inactive, .background:
                    self.saveContext()
                    self.player.removePeriodicTimeObserver()
                @unknown default:
                    fatalError("Unknown case")
            }
        }
    }
    
    // MARK: - Core Data stack
    
    private var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Songs")
        container.loadPersistentStores { description, error in
            if let error = error {
                // TODO: Add your error UI here
                fatalError("Unable to load conatainer with \(error)")
            }
            print(description)
        }
        print("Making persistant container")
        return container
    }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Show the error here
                fatalError("Unresolved error \(error)")
            }
        }
    }
}
