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
    
    @Environment(ViewModel.self) private var model
    @Bindable var configuration: GlobeConfiguration
       
    var body: some View {
        RealityView { content in
            log("Make", globeName: configuration.globe.name, category: "RealityView.make")

            if let globeEntity = configuration.globeEntity {
                content.add(globeEntity)
            }
        } update: { content in
            log("Update", globeName: configuration.globe.name, category: "RealityView.update")

            let oldGlobeEntity = content.entities.first(where: { $0 is GlobeEntity })
            let replaceGlobe = oldGlobeEntity?.name != configuration.globeEntity?.name
            
            // if the globe changed, remove the old entity and add the new entity
            if replaceGlobe {
                log("Update replacing old globe with ", globeName: configuration.globe.name, category: "RealityView.update")
                
                if let oldGlobeEntity {
                    content.remove(oldGlobeEntity)
                }
                if let globeEntity = configuration.globeEntity {
                    content.add(globeEntity)
                }
            }
            
            configuration.globeEntity?.update(configuration: configuration)
        }
        .globeGestures(configuration: configuration)
    }
    
    private func log(_ message: String, globeName: String, category: String) {
        let logger = Logger(subsystem: "Immersive Globe View", category: category)
        logger.info("\(message) \"\(globeName)\"" )
    }
}

#if DEBUG
#Preview(immersionStyle: .mixed) {
    ImmersiveGlobeView(configuration: .init(globe: Globe.preview, adjustRotationSpeedToSize: true))
        .environment(ViewModel.preview)
}
#endif
