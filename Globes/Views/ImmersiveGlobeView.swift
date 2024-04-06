//
//  ImmersiveGlobeView.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/3/2024.
//

import os
import RealityKit
import SwiftUI

/// Immersive globe for rendering full-size globes.
struct ImmersiveGlobeView: View {
    
    /// The current configuration of the globe displayed by this view. This is bindable, because gesture handlers can change configuration variables.
    @Bindable var configuration: GlobeConfiguration
    
    /// True if the `configuration.globeEntity` changed and the entity displayed by this view needs to be replaced.
    @State private var globeEntityChanged = false
    
    var body: some View {
        RealityView { content in
            log("Make", globeName: configuration.globe.name, category: "RealityView.make")

            if let globeEntity = configuration.globeEntity {
                content.add(globeEntity)
            }
        } update: { content in
            log("Update", globeName: configuration.globe.name, category: "RealityView.update")

            // if the globe changed, remove the old entity and add the new entity
            if globeEntityChanged {
                log("Update replacing old globe with", globeName: configuration.globe.name, category: "RealityView.update")
                
                if let oldGlobeEntity = content.entities.first(where: { $0 is GlobeEntity }) {
                    content.remove(oldGlobeEntity)
                }
                if let globeEntity = configuration.globeEntity {
                    content.add(globeEntity)
                }
                Task { @MainActor in
                    globeEntityChanged = false
                }
            }
            
            configuration.globeEntity?.update(configuration: configuration)
        }
        .globeGestures(configuration: configuration)
        .onChange(of: configuration.globeEntity) {
            Task { @MainActor in
                globeEntityChanged = true
            }
        }
    }
    
    private func log(_ message: String, globeName: String, category: String) {
#if DEBUG
        let logger = Logger(subsystem: "Immersive Globe View", category: category)
        logger.info("\(message) \"\(globeName)\"" )
#endif
    }
}

#if DEBUG
#Preview(immersionStyle: .mixed) {
    ImmersiveGlobeView(configuration: .init(globe: Globe.preview, adjustRotationSpeedToSize: true))
}
#endif
