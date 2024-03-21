//
//  ContentView.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/3/2024.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    let globes: [Globe]
    
    @Environment(ViewModel.self) private var model
    
    @State private var immersiveSpaceIsShown = false
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    @State private var webViewStatus: WebViewStatus = .loading
    
    private var selectedGlobe: Globe? { model.selectedGlobeConfiguration?.globe }
    
    var body: some View {
        if model.webURL != nil {
            webView
        } else {
            navigationView
        }
    }
    
    @ViewBuilder private var webView: some View {
        let url = model.webURL ?? URL(string: "https://www.davidrumsey.com")!
        
        ZStack {
            WebView(url: url, status: $webViewStatus)
            
            switch webViewStatus {
            case .loading:
                ProgressView("Loading Page")
                    .padding()
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
            case .finishedLoading:
                EmptyView()
            case .failed(let error):
                VStack {
                    Text("The page could not be loaded.")
                    Text(error.localizedDescription)
                }
                .padding()
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            HStack {
                Button(action: {
                    model.webURL = nil
                }) {
                    Label("Go Back to Globes", systemImage: "chevron.left")
                }
                .labelStyle(.iconOnly)
                .help("Go Back to Globes")
                .padding()
                
                Link("Open in Safari", destination: url)
                    .padding()
            }
            .glassBackgroundEffect()
        }
    }
    
    @ViewBuilder private var navigationView: some View {
        NavigationSplitView {
            IntroView()
                .padding(.horizontal)
                .navigationSplitViewColumnWidth(280)
        } detail: {
            HStack {
                ScrollView(.vertical) {
                    VStack(spacing: 6) {
                        ForEach(globes) { globe in
                            GlobeSelectionView(globe: globe)
                        }
                    }
                    .scrollTargetLayout() // for scrollTargetBehavior
                }
                .padding(.horizontal)
                .scrollTargetBehavior(.viewAligned) // align views with border of scroll view
                .scrollIndicators(.never)
                .frame(minWidth: 0, maxWidth: .infinity) // enforce two columns of identical width
                
                ZStack {
                    GlobeInfoView()
                        .padding()
                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
                        .opacity(selectedGlobe == nil ? 0 : 1)
                    
                    Text("Select a Globe")
                        .font(.title)
                        .padding(.bottom, 50)
                        .opacity(selectedGlobe == nil ? 1 : 0)
                }
                .padding(.horizontal)
                .padding(.trailing)
                .padding(.bottom, 30)
                .frame(minWidth: 0, maxWidth: .infinity) // enforce two columns of identical width
                
                .toolbar {
                    if selectedGlobe != nil {
                        ToolbarItem(placement: .topBarTrailing) {
                            resetSizeButton
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            pauseRotationButton
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            hideGlobeButton
                        }
                    }
                }
                
                .navigationSplitViewColumnWidth(min: 600, ideal: 1000)
            }
        }
        .onChange(of: selectedGlobe) { _, newSelectedGlobe in
            if newSelectedGlobe == nil {
                Task {
                    if immersiveSpaceIsShown {
#warning("Passing argument of non-sendable type 'DismissImmersiveSpaceAction' into main actor-isolated context may introduce data races")
                        await dismissImmersiveSpace()
                    }
                    immersiveSpaceIsShown = false
                }
            } else {
                Task {
                    guard !immersiveSpaceIsShown else { return }
                    switch await openImmersiveSpace(id: "ImmersiveGlobeSpace") {
                    case .opened:
                        immersiveSpaceIsShown = true
                    case .error, .userCancelled:
                        fallthrough
                    @unknown default:
                        immersiveSpaceIsShown = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder private var hideGlobeButton: some View {
        Button(action: {
            model.selectedGlobeConfiguration = nil
        }) {
            Label("Hide the Globe", systemImage: "xmark")
                .labelStyle(.iconOnly)
        }
        .padding()
        .help("Hide the Globe")
    }
    
    @ViewBuilder private var resetSizeButton: some View {
        let globeIsScaled = model.selectedGlobeConfiguration?.globeEntity?.globeScale != 1
        Button(action: {
            model.selectedGlobeConfiguration?.globeEntity?.globeScale = 1
        }) {
            Label("Reset the Globe to its Original Size", systemImage: "circle.circle")
                .labelStyle(.iconOnly)
        }
        .disabled(!globeIsScaled)
        .padding()
        .help(globeIsScaled ? "Reset to Original Size" : "The Globe is at its Original Size")
    }
    
    private var isRotationPausedBinding: Binding<Bool> {
        Binding(get: {
            model.selectedGlobeConfiguration?.isRotationPaused == true
        }, set: {
            model.selectedGlobeConfiguration?.isRotationPaused = $0
        })
    }
    
    @ViewBuilder private var pauseRotationButton: some View {
        Toggle(isOn: isRotationPausedBinding) {
            if isRotationPausedBinding.wrappedValue {
                Label("Globe Rotation", image: "rotate.3d.slash")
            } else {
                Label("Globe Rotation", systemImage: "rotate.3d")
            }
        }
        .labelStyle(.iconOnly)
        .toggleStyle(.button)
        .padding()
        .help(isRotationPausedBinding.wrappedValue ? "Start Globe Rotation" : "Stop Globe Rotation")
    }
}

#if DEBUG
#Preview(windowStyle: .automatic) {
    ContentView(globes: Globe.previewGlobes + Globe.previewGlobes)
        .environment(ViewModel.preview)
    
}
#endif
