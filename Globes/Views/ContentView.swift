//
//  ContentView.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/3/2024.
//

import SwiftUI
import RealityKit

@MainActor
struct ContentView: View {
    let globes: [Globe]
    
    @Environment(ViewModel.self) var model
    
    @Binding var immersiveSpaceIsShown: Bool
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    @State private var webViewStatus: WebViewStatus = .loading
    
    var body: some View {
        
        Group {
            if model.webURL != nil {
                webView
            } else {
                navigationView
            }
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
    }
    
    private var selectedGlobe: Globe? { model.selectedGlobeConfiguration?.globe }
    
    private var showAlertBinding: Binding<Bool> {
        Binding(
            get: { model.errorToShowInAlert != nil },
            set: {
                if $0 == false {
                    model.errorToShowInAlert = nil
                }
            })
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
                    
                    VStack {
                        Text("Select a Globe")
                            .font(.title)
                        Spacer()
                    }
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
                            orientButton
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
        .onChange(of: selectedGlobe) {
            Task { @MainActor in
                guard selectedGlobe != nil, !immersiveSpaceIsShown else { return }
                
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
    
    @ViewBuilder private var hideGlobeButton: some View {
        Button(action: {
            Task { @MainActor in
                if immersiveSpaceIsShown {
                    await dismissImmersiveSpace()
                }
                immersiveSpaceIsShown = false
                model.deselectGlobe()
            }
        }) {
            Label("Hide the Globe", systemImage: "arrow.down.forward.and.arrow.up.backward")
                .labelStyle(.iconOnly)
        }
        .padding()
    }
    
    @ViewBuilder private var orientButton: some View {
        Button(action: { model.selectedGlobeConfiguration?.resetOrientation() } ) {
            Label("Orient the Globe", systemImage: "location.north.line")
                .labelStyle(.iconOnly)
        }
        .disabled(model.selectedGlobeConfiguration?.isNorthOriented ?? true)
        .padding()
    }
    
    @ViewBuilder private var resetSizeButton: some View {
        let globeIsAtOriginalSize = model.selectedGlobeConfiguration?.scale == 1
        
        Button(action: resetGlobeSize) {
            Label("Reset the Globe to its Original Size", systemImage: "circle.circle")
                .labelStyle(.iconOnly)
        }
        .disabled(globeIsAtOriginalSize)
        .padding()
    }
    
    private func resetGlobeSize() {
        guard let configuration = model.selectedGlobeConfiguration else { return }
        configuration.scaleAndAdjustDistanceToCamera(
            newScale: 1,
            oldScale: configuration.scale,
            oldPosition: configuration.position,
            cameraPosition: nil
        )
    }
    
    @ViewBuilder private var pauseRotationButton: some View {
        let isRotationPausedBinding: Binding<Bool> = Binding(
            get: { model.selectedGlobeConfiguration?.isRotationPaused == true },
            set: { model.selectedGlobeConfiguration?.isRotationPaused = $0 }
        )
        
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
    }
}

#if DEBUG
#Preview(windowStyle: .automatic) {
    ContentView(globes: Globe.previewGlobes, immersiveSpaceIsShown: .constant(false))
        .environment(ViewModel.preview)
    
}
#endif
