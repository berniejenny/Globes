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
    @Environment(ViewModel.self) var model
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    
    let globes: [Globe]
    @Binding var immersiveSpaceIsShown: Bool
    
    private var selectedGlobe: Globe? { model.selectedGlobeConfiguration?.globe }
    
    var body: some View {
        Group {
            if model.webURL != nil {
                WebViewDecorated()
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
    
    private var showAlertBinding: Binding<Bool> {
        Binding(
            get: { model.errorToShowInAlert != nil },
            set: {
                if $0 == false {
                    model.errorToShowInAlert = nil
                }
            })
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
                        GlobesToolbarContent(immersiveSpaceIsShown: $immersiveSpaceIsShown)
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
}

#if DEBUG
#Preview(windowStyle: .automatic) {
    ContentView(globes: Globe.previewGlobes, immersiveSpaceIsShown: .constant(false))
        .environment(ViewModel.preview)
    
}
#endif
