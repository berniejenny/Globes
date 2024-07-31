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
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize: DynamicTypeSize
   
    @ScaledMetric private var scaledWidthSettings = 500.0
    @ScaledMetric private var scaledMinWidthGallery = GlobeSelectionView.viewMinWidth + 48
    @ScaledMetric private var scaledMinWidthSearch = GlobeSelectionView.viewMinWidth + 500
    @ScaledMetric private var scaledMinWidthSearchAccessibleTypeSize = GlobeSelectionView.viewMinWidth + 200
    @ScaledMetric private var scaledMinWidthPlay = GlobeView.viewWidth * 2 + 450
    @ScaledMetric private var scaledMinWidthPlayAccessibleTypeSize = GlobeView.viewWidth + 450
    @ScaledMetric private var scaledMinWidthAbout = 620.0
    @ScaledMetric private var scaledMinWidthSharePlay = 500.0
    
    private enum Tab {
        case gallery, favorites, play, search, createGlobe, settings, about, sharePlay
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
            AnimateView()
                .tabItem { Label("Animate", systemImage: "play") }
                .tag(Tab.play)
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)
//            CreateGlobeView()
//                .tabItem { Label("Create a Globe", systemImage: "hammer") }
//                .tag(Tab.createGlobe)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(Tab.settings)
            SharePlayView()
                .tabItem { Label("SharePlay", systemImage: "shareplay") }
                .tag(Tab.sharePlay)
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
        .frame(width: scaledWidth, height: scaledHeight)
        .frame(minWidth: scaledMinWidth, minHeight: scaledMinHeight)
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
    
    private var scaledWidth: CGFloat? {
        selectedTab == .settings ? scaledWidthSettings : nil
    }
    
    private var scaledHeight: CGFloat? {
        if selectedTab == .settings {
            switch dynamicTypeSize {
            case .xSmall, .small, .medium:
                return 680
            case .large:
                return 740
            case .xLarge:
                return 755
            case .xxLarge:
                return 775
            case .xxxLarge:
                return 810
            case .accessibility1:
                return 845
            case .accessibility2:
                return 880
            case .accessibility3:
                return 940
            case .accessibility4:
                return 1000
            case .accessibility5:
                return 1110
            @unknown default:
                return 880
            }
        } else {
            return nil
        }
    }
    
    private var scaledMinWidth: CGFloat? {
        switch selectedTab {
        case .gallery, .favorites:
            scaledMinWidthGallery
        case .play:
            dynamicTypeSize.isAccessibilitySize ? scaledMinWidthPlayAccessibleTypeSize : scaledMinWidthPlay
        case .search:
            dynamicTypeSize.isAccessibilitySize ? scaledMinWidthSearchAccessibleTypeSize : scaledMinWidthSearch
        case .createGlobe:
            nil
        case .settings:
            scaledWidthSettings
        case .about:
            scaledMinWidthAbout
        case .sharePlay:
            scaledMinWidthSharePlay
        }
    }
    
    private var scaledMinHeight: CGFloat? {
        switch selectedTab {
        case .gallery:
            330
        case .favorites:
            316
        case .play:
            550
        case .search:
            550
        case .createGlobe:
            600
        case .settings:
            nil
        case .about:
            dynamicTypeSize.isAccessibilitySize ? 1000 : 700
        case .sharePlay:
            500
        }
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
