//
//  GlobesApp.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/3/2024.
//

import SwiftUI

@main
struct GlobesApp: App {
    
    /// Globes loaded from Globes.json in the app bundle
    private let globes: [Globe]
    
    /// View model injected in environment.
    @State private var model = ViewModel()
    
    @State private var globeImmersionStyle: ImmersionStyle = .mixed
    @State private var immersiveSpaceIsShown = false
    
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
        
        // start camera tracking 
        CameraTracker.start()
    }
        
    var body: some Scene {
        // window for selecting a globe and displaying information about a globe
        WindowGroup {
            ContentView(globes: globes, immersiveSpaceIsShown: $immersiveSpaceIsShown)
                .frame(minWidth: 900, maxWidth: 1300, minHeight: 600) // this defines min and max dimensions of the window
                .environment(model)
        }
        .windowResizability(.contentSize) // window resizability is derived from window content
        
        // immersive globe space
        ImmersiveSpace(id: "ImmersiveGlobeSpace") {
            if let configuration = model.selectedGlobeConfiguration {
                ImmersiveGlobeView(configuration: configuration)
                    .environment(model)
                    .onDisappear {
                        // Handle home button press that dismisses the immersive view.
                        // No need to call dismissImmersiveSpace
                        immersiveSpaceIsShown = false
                        model.deselectGlobe()
                    }
            }
        }
        .immersionStyle(selection: $globeImmersionStyle, in: .mixed)
    }
}
