//
//  GlobesApp.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/3/2024.
//

import SwiftUI

@main
struct GlobesApp: App {
    
    /// List of globe loaded from Globes.json in the app bundle
    private let globes: [Globe]
    
    /// View model injected in environment.
    @State private var model = ViewModel()
    
    @State private var globeImmersionStyle: ImmersionStyle = .mixed
    
    init() {
        // Register custom components and systems
        RotationComponent.registerComponent()
        RotationSystem.registerSystem()
        
        // load Globes.json
        do {
            let url = Bundle.main.url(forResource: "Globes", withExtension: "json")!
            let data = try Data(contentsOf: url)
            globes = try JSONDecoder().decode([Globe].self, from: data)
        } catch {
            fatalError("An error occurred when loading Globes.json from the bundle: \(error.localizedDescription)")
        }
    }
        
    var body: some Scene {
        // window for selecting a globe and displaying information about a globe
        WindowGroup {
            ContentView(globes: globes)
                .environment(model)
        }
//        .defaultSize(width: 550, height: 800)
        .windowResizability(.contentMinSize)
        
        // immersive globe space
        ImmersiveSpace(id: "ImmersiveGlobeSpace") {
            if let configuration = model.selectedGlobeConfiguration {
                ImmersiveGlobeView(configuration: configuration)
                    .environment(model)
                    .onDisappear {
                        // handle home button press that closes the immersive view
                        model.selectedGlobeConfiguration = nil
                    }
            }
        }
        .immersionStyle(selection: $globeImmersionStyle, in: .mixed)
    }
}
