//
//  PanoramaButton.swift
//  Globes
//
//  Created by Bernhard Jenny on 5/5/2024.
//

import SwiftUI

struct PanoramaButton: View {
    @Environment(ViewModel.self) private var model
    @Environment(\.openImmersiveSpace) var openImmersiveSpaceAction
    
    let globe: Globe
    
    @MainActor
    private var isSelected: Bool {
        model.panoramaGlobe?.id == globe.id
    }
    
    @MainActor
    private var showLoadingProgress: Bool {
        model.isLoadingPanorama && model.panoramaGlobeToLoad?.id == globe.id
    }
    
    var body: some View {
        ZStack {
            Button(action: {
                if isSelected  {
                    model.hidePanorama()
                } else {
                    model.loadPanorama(globe: globe, openImmersiveSpaceAction: openImmersiveSpaceAction)
                }
            }) {
                ButtonImage(name: isSelected ? "pano.fill" : "pano")
                    .foregroundColor(isSelected ? .accentColor : .primary)
            }
            .buttonStyle(.plain)
            .opacity(showLoadingProgress ? 0.05 : 1) // don't completely hide the button otherwise focus jumps to a neighboring button while the globe is loaded
            .disabled(showLoadingProgress)
            
            ProgressView()
                .controlSize(.mini)
                .opacity(showLoadingProgress ? 1 : 0)
        }
    }
}
