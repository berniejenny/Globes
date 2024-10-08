//
//  SharePlayTestGlobesApp.swift
//  SharePlayTestGlobes
//
//  Created by BooSung Jung on 7/10/2024.
//

import SwiftUI
import SwiftData

@main
struct SharePlayTestGlobesApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
