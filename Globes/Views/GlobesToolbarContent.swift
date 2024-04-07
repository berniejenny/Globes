//
//  GlobesToolbarContent.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/4/2024.
//

import SwiftUI

struct GlobesToolbarContent: ToolbarContent {
    @Environment(ViewModel.self) var model
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Binding var immersiveSpaceIsShown: Bool
    
    @MainActor
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            resetSizeButton.padding()
        }
        ToolbarItem(placement: .topBarTrailing) {
            orientButton.padding()
        }
        ToolbarItem(placement: .topBarTrailing) {
            pauseRotationButton.padding()
        }
        ToolbarItem(placement: .topBarTrailing) {
            hideGlobeButton.padding()
        }
    }
    
    @MainActor
    @ViewBuilder private var resetSizeButton: some View {
        let globeIsAtOriginalSize = model.selectedGlobeConfiguration?.scale == 1
        
        Button(action: resetGlobeSize) {
            Label("Reset the Globe to its Original Size", systemImage: "circle.circle")
                .labelStyle(.iconOnly)
        }
        .disabled(globeIsAtOriginalSize)
    }
    
    @MainActor
    private func resetGlobeSize() {
        guard let configuration = model.selectedGlobeConfiguration else { return }
        configuration.scaleAndAdjustDistanceToCamera(
            newScale: 1,
            oldScale: configuration.scale,
            oldPosition: configuration.position,
            cameraPosition: nil,
            animate: true
        )
    }
    
    @MainActor
    @ViewBuilder private var orientButton: some View {
        Button(action: {
            model.selectedGlobeConfiguration?.resetOrientation(animate: true)
        } ) { @MainActor in
            Label("Orient the Globe", systemImage: "location.north.line")
                .labelStyle(.iconOnly)
        }
        .disabled(model.selectedGlobeConfiguration?.isNorthOriented ?? true)
    }
    
    @MainActor
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
    }
}
