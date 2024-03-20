//
//  ImmersiveGlobeView.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/3/2024.
//

import os
import RealityKit
import SwiftUI

/// Immersive globe for rendering small preview globes and full-size globes.
struct ImmersiveGlobeView: View {
    
    @Environment(ViewModel.self) private var model
    @Bindable var configuration: GlobeEntity.Configuration
        
    /// Accessibility stuff required by `PlacementGesturesModifier`
    @State var axZoomIn: Bool = false
    @State var axZoomOut: Bool = false
    
    /// A hack to override the radius of `configuration`.
    var overrideRadius: Float? = nil
    private var radius: Float { overrideRadius ?? configuration.globe.radius }
   
    private func statusLog(_ message: String, globeName: String, category: String) {
        let logger = Logger(subsystem: "Immersive Globe View", category: category)
        logger.info("\(message) \"\(globeName)\"" )
    }
    
    var body: some View {
        RealityView { content in
            statusLog("Make", globeName: configuration.globe.name, category: "RealityView.make")
            let globeEntity = await GlobeEntity(radius: radius, configuration: configuration)
            content.add(globeEntity)
            configuration.globeEntity = globeEntity
        } update: { content in
            let oldGlobeEntity = content.entities.first(where: { $0 is GlobeEntity })
            guard oldGlobeEntity?.name != configuration.globeEntity?.name else {
                configuration.globeEntity?.update(configuration: configuration)
                return
            }
            
            // if the globe changed, remove the old entity and add the new entity
            if let oldGlobeEntity {
                statusLog("Update: Remove", globeName: oldGlobeEntity.name, category: "RealityView.update")
                content.remove(oldGlobeEntity)
            }
            
            // add the globe if there is none
            if let globeEntity = configuration.globeEntity {
                statusLog("Update: Add globe", globeName: configuration.globe.name, category: "RealityView.update")
                content.add(globeEntity)
            }
            
            configuration.globeEntity?.update(configuration: configuration)
        }
        .placementGestures(configuration: configuration, axZoomIn: axZoomIn, axZoomOut: axZoomOut)
    }
}

#if DEBUG
#Preview(immersionStyle: .mixed) {
    ImmersiveGlobeView(configuration: .init(globe: Globe.preview))
        .environment(ViewModel.preview)
}
#endif
