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
   
    private var selectedGlobe: Globe? { model.selectedGlobeConfiguration?.globe }
    
    var body: some View {
        VStack {
            if model.selectedGlobeConfiguration == nil {
                // no globe currently selected, show list of globes
                ScrollView(.vertical) {
                    VStack(spacing: 6) {
                        ForEach(globes) { globe in
                            GlobeSelectionView(globe: globe)
                        }
                    }
                    .scrollTargetLayout() // for scrollTargetBehavior
                }
                .scrollTargetBehavior(.viewAligned) // align views with border of scroll view
                .scrollIndicators(.never)
            } else {
                // show info for the selected globe
                GlobeInfoView()
            }
            Spacer(minLength: 0)
        }
        .frame(width: 400)
        .padding(40)
        
        .onChange(of: selectedGlobe) { _, newSelectedGlobe in
            if newSelectedGlobe == nil {
                Task {
                    if immersiveSpaceIsShown {
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
}

#Preview(windowStyle: .automatic) {
    ContentView(globes: Globe.previewGlobes + Globe.previewGlobes)
        .environment(ViewModel.preview)
    
}
