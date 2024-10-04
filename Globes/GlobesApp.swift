//
//  GlobesApp.swift
//  Globes
//
//  Created by Bernhard Jenny on 2/5/2024.
//

import os
import SwiftUI

#if DEBUG
import SharePlayMock
#endif

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

@available(visionOS 1.1, *)
@main
struct GlobesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openURL) private var openURL
    @Environment(\.openImmersiveSpace) private var openImmersiveSpaceAction // ADDED this
    
    /// View model injected in environment. @State instead of the old @StateObject is fine with the new Observable framework.
    @State private var model = ViewModel.shared
   
    
    
    init() {
#if DEBUG
         
#endif
        // When the application starts, we will configure the group sessions for shareplay
        model.configureGroupSessions()
        Registration.registerGroupActivity()
    }
    var body: some Scene {
        WindowGroup {
            GeometryReader3D { proxy in
                ContentView()
                    .environment(model)
                    .onAppear {
                        model.openImmersiveSpaceAction = openImmersiveSpaceAction // Pass the openImmersiveSpaceAction to the ViewModel
                        model.openImmersiveGlobeSpace(openImmersiveSpaceAction)
                    }
                    .onChange(of: proxy.frame(in: .immersiveSpace).center, initial: true) {
                        let windowCenter = proxy.frame(in: .immersiveSpace).center
                        Task { @MainActor in
                            model.windowCenter = windowCenter
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
//                .handlesExternalEvents(
////
////                    // There are two scenes but we need to tell shareplay which scene Can and Prefers
////                    // https://developer.apple.com/videos/play/wwdc2023/10087/?time=248
////
//                    preferring: ["planet"],
//                    allowing: ["planet"]
//                )
        
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
