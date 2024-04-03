//
//  ViewModel.swift
//  Globes
//
//  Created by Bernhard Jenny on 15/3/2024.
//

import SwiftUI

@Observable class ViewModel {    
    /// The configuration of the currently selected globe. Nil if no globe is selected.
    private(set) var selectedGlobeConfiguration: GlobeConfiguration? = nil
    
    /// Hide small preview globes when an alert, a confirmation dialog or a sheet is shown to avoid intersections between these views and the globes
    var hidePreviewGlobes = false
    
    /// If non-nil the main window is displaying this web page.
    var webURL: URL? = nil
    
    /// Set `selectedGlobeConfiguration` to nil.
    func deselectGlobe() {
        selectedGlobeConfiguration = nil
    }
    
    /// Load a globe.
    /// - Parameter configuration: Configuration settings.
    func loadGlobe(configuration: GlobeConfiguration) async throws {
        let oldGlobeEntity = selectedGlobeConfiguration?.globeEntity
        let newGlobeEntity = try await GlobeEntity(configuration: configuration)
        let oldRadius = selectedGlobeConfiguration?.globe.radius ?? configuration.globe.radius
        
        if let selectedGlobeConfiguration {
            // replace the globe metadata, but reuse other settings, such as the rotation toggle.
            selectedGlobeConfiguration.globe = configuration.globe
        } else {
            // there is no previous globe
            selectedGlobeConfiguration = configuration
        }
        selectedGlobeConfiguration?.globeEntity = newGlobeEntity
        
        // position the new globe such that its closest part is at the same distance as the closest part of the old globe
        if let oldGlobeEntity {
            // scaled radius of the globe
            let oldScaledRadius = await oldRadius * oldGlobeEntity.uniformScale
            // the new globe (with scale = 1) differs by this factor in size from the old globe
            let oldScale = oldScaledRadius / configuration.globe.radius
            await newGlobeEntity.scaleAndAdjustDistanceToCamera(
                newScale: 1,
                oldScale: oldScale,
                oldPosition: oldGlobeEntity.position,
                globeRadius: configuration.globe.radius
            )
        } else {
            // position the globe in front of the camera
            let radius = configuration.globe.radius
            let globeCenter = SIMD3<Float>([0, 1, -(radius + 0.5)])
            await newGlobeEntity.setPosition(globeCenter, relativeTo: nil)
        }
    }
}
