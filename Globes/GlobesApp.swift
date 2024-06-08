//
//  GlobesApp.swift
//  Globes
//
//  Created by Bernhard Jenny on 2/5/2024.
//

import SwiftUI

@main
struct GlobesApp: App {
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openURL) private var openURL
    
    /// View model injected in environment.
    @State private var model = ViewModel()
        
    init() {
        // register custom components and systems
        RotationComponent.registerComponent()
        RotationSystem.registerSystem()
        GlobeBillboardComponent.registerComponent()
        GlobeBillboardSystem.registerSystem()        
        
        // start camera tracking
        CameraTracker.start()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                //.frame(minWidth: 500, minHeight: 330)
                .environment(model)
        }
        .windowResizability(.contentSize) // window resizability is derived from window content
        
        WindowGroup(id: "info", for: UUID.self) { $globeId in
            if let infoURL = model.globes.first(where: { $0.id == globeId })?.infoURL {
                WebViewDecorated(url: infoURL)
                    .ornament(attachmentAnchor: .scene(.bottom)) {
                        Button("Open in Safari") { openURL(infoURL) }
                        .padding()
                        .glassBackgroundEffect()
                    }
                    .frame(minWidth: 500)
            }
        }
        .windowResizability(.contentSize) // window resizability is derived from window content
                
        ImmersiveSpace(id: "ImmersiveGlobeSpace") {
            ImmersiveGlobeView()
                .environment(model)
                .onDisappear {
                    // Handle home button press that dismisses the immersive view.
                    // No need to call dismissImmersiveSpace
                    model.immersiveSpaceIsShown = false
                    model.hideAllGlobes()
                    model.hidePanorama()
                }
        }
        .immersionStyle(selection: immersionStyleBinding, in: .mixed, .progressive, .full)
    }
    
    @MainActor
    private var immersionStyleBinding: Binding<any ImmersionStyle> {
        Binding(get: {
            let showPanorama = model.isShowingPanorama && model.panoramaEntity != nil
            if showPanorama {
                return model.panoramaImmersionStyle.immersionStyle
            } else {
                return .mixed
            }
        }, set: { _ in
            // from the documentation: "Even though you provide a binding, the value changes only if you change it."
        })
    }
}
