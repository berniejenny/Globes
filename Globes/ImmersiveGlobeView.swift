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
    var configuration: GlobeEntity.Configuration
    
    @State private var globeEntity: GlobeEntity?
    
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
            let globeEntity = await GlobeEntity(
                radius: radius,
                configuration: configuration
            )
            content.add(globeEntity)
            self.globeEntity = globeEntity
        } update: { content in
            // if the globe changed, remove the old entity and add the new entity
            if let oldGlobeEntity = content.entities.first(where: { $0 is GlobeEntity }),
               oldGlobeEntity.name != configuration.globe.name {
                statusLog("Update: Remove", globeName: oldGlobeEntity.name, category: "RealityView.update")
                content.remove(oldGlobeEntity)
            }
            
            // add the globe if there is none
            if content.entities.first(where: {$0 is GlobeEntity }) == nil,
                let globeEntity {
                statusLog("Update: Add globe", globeName: globeEntity.name, category: "RealityView.update")
                content.add(globeEntity)
            }
            globeEntity?.update(configuration: configuration)
        }
        .placementGestures(globeEntity: globeEntity, axZoomIn: axZoomIn, axZoomOut: axZoomOut)
    }
}

#if DEBUG
#Preview(immersionStyle: .mixed) {
    ImmersiveGlobeView(configuration: .init(globe: Globe.preview))
}
#endif
