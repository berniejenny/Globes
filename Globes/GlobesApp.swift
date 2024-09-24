//
//  GlobesApp.swift
//  Globes
//
//  Created by Bernhard Jenny on 2/5/2024.
//

import os
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // register custom components and systems
        RotationComponent.registerComponent()
        RotationSystem.registerSystem()
        GlobeBillboardComponent.registerComponent()
        GlobeBillboardSystem.registerSystem()
        
        // start camera tracking
        CameraTracker.start()
        
        return true
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        guard let globeID = ViewModel.shared.configurations.keys.first else { return }
        if Thread.current.isMainThread {
            ViewModel.shared.configurations[globeID] = nil
            ViewModel.shared.globeEntities[globeID] = nil
        } else {
            Task { @MainActor in
                ViewModel.shared.configurations[globeID] = nil
                ViewModel.shared.globeEntities[globeID] = nil
            }
        }
        Logger().info("Globes received a memory warning and will close one globe.")
    }
}

@main
struct GlobesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openURL) private var openURL
    @Environment(\.openImmersiveSpace) var openImmersiveSpaceAction
    
    /// View model injected in environment. @State instead of the old @StateObject is fine with the new Observable framework.
    @State private var model = ViewModel.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .onAppear() {
                    if !model.immersiveSpaceIsShown {
                        Task { @MainActor in
                            await model.openImmersiveSpace(with: openImmersiveSpaceAction)
                        }
                    }
                }
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
                    // Handle home button press that dismisses the immersive view, or the system closing the immersive space.
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
