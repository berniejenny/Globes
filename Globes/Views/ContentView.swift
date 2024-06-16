//
//  ContentView.swift
//  Globes
//
//  Created by Bernhard Jenny on 2/5/2024.
//

import RealityKit
import SwiftUI

struct ContentView: View {
    @Environment(ViewModel.self) var model

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    private enum Tab {
        case gallery, favorites, play, search, createGlobe, settings, about
        
        var minWidth: Double {
            switch self {
            case .gallery, .favorites, .play, .settings:
                540
            case .search, .createGlobe:
                800
            case .about:
                650
            }
        }
        
        var minHeight: Double {
            switch self {
            case .gallery:
                330
            case .favorites:
                316
            case .play:
                500
            case .search:
                500
            case .createGlobe:
                600
            case .settings:
                725
            case .about:
                700
            }
        }
    }
    
    @State private var selectedTab = Tab.gallery
    
    @MainActor
    private var showAlertBinding: Binding<Bool> {
        Binding(
            get: { model.errorToShowInAlert != nil },
            set: {
                if $0 == false {
                    model.errorToShowInAlert = nil
                }
            })
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GalleryView()
                .tabItem { Label("Globes", systemImage: "globe") }
                .tag(Tab.gallery)
            FavoritesView()
                .tabItem { Label("Favorites", systemImage: "heart") }
                .tag(Tab.favorites)
//            PlayView()
//                .tabItem { Label("Play", systemImage: "play") }
//                .tag(Tab.play)
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)
#warning("Create custom globe")
//            CreateGlobeView()
//                .tabItem { Label("Create a Globe", systemImage: "hammer") }
//                .tag(Tab.createGlobe)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(Tab.settings)
            AboutView()
                .tabItem { Label("About", systemImage: "ellipsis") }
                .tag(Tab.about)
        }
        .alert(
            model.errorToShowInAlert?.localizedDescription ?? "An error occurred.",
            isPresented: showAlertBinding,
            presenting: model.errorToShowInAlert
        ) { _ in
            // default OK button
        } message: { error in
            if let message = error.alertSecondaryMessage {
                Text(message)
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .top) {
            bottomOrnament
        }
        .onChange(of: model.scrollGalleryToGlobe) {
            Task { @MainActor in
                guard model.scrollGalleryToGlobe != nil else { return }
                try await Task.sleep(for: .seconds(0.1))
                selectedTab = .gallery
            }
        }
        .onChange(of: scenePhase, initial: false) { _, newScenePhase in
            // Close all info windows and the immersive space when the main window is closed.
            if newScenePhase == .background {
                closeWindowsAndImmersiveSpace()
            }
        }
        .frame(minWidth: selectedTab.minWidth, minHeight: selectedTab.minHeight)
    }
    
    @ViewBuilder
    @MainActor
    private var bottomOrnament: some View {
        HStack {
            Button(action: model.hideAllGlobes) {
                Label("Globes", image: "globe.slash")
            }
            .disabled(model.configurations.isEmpty)
            
            Button(action: model.hidePanorama) {
                Label("Panorama Globe", image: "pano.fill.slash")
            }
            .disabled(!model.isShowingPanorama)
            
            debugButtons
        }
        .toggleStyle(.button)
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
        .padding()
        .glassBackgroundEffect()
        .padding()
    }
    
    @MainActor
    private func closeWindowsAndImmersiveSpace() {
        // close all info windows
        dismissWindow(id: "info")
        
        // Close the immersive space.
        // See https://forums.developer.apple.com/forums/thread/748290?answerId=783121022#783121022
        // Important: This must be placed here. https://developer.apple.com/documentation/swiftui/scenephase
        // If onChange(of: scenePhase) is placed in the App struct, the scenePhase value is an aggregate for all windows
        // This is a problem with auxiliary windows: if they are closed, a background scene phase is received in the App struct, no matter whether
        // the onChange handler is attached to the main WindowGroup or the auxiliary WindowGroup.
        if model.immersiveSpaceIsShown {
            Task {
                await dismissImmersiveSpace()
                await MainActor.run {
                    model.hideAllGlobes()
                    model.hidePanorama()
                }
            }
            Task { @MainActor in
                model.immersiveSpaceIsShown = false
            }
        }
    }
    
    @ViewBuilder
    @MainActor
    private var debugButtons: some View {
#if DEBUG
            Button(action: {
                model.errorToShowInAlert = error("Debug Info", secondaryMessage: String(reflecting: model))
                print(model)
            }) {
                Label("Debug Info", systemImage: "ant")
            }
            .foregroundColor(.red)
            
            Button(action: {
                UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                UserDefaults.standard.synchronize()
                model.errorToShowInAlert = error("Erased UserDefaults")
            }) {
                Label("Debug Info", systemImage: "eraser")
            }
            .foregroundColor(.red)
#endif
    }
}

#if DEBUG
#Preview(windowStyle: .automatic) {
    GeometryReader { proxy in
        ZStack {
            ContentView()
                .environment(ViewModel.preview)
            Text("\(proxy.size)")
                .padding()
                .glassBackgroundEffect()
        }
    }
    .glassBackgroundEffect()
}
#endif
