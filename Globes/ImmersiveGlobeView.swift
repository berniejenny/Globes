//
//  ImmersiveGlobeView.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/3/2024.
//

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
   
    var body: some View {
        RealityView { content in
            print("* Make", configuration.globe.name)
            let globeEntity = await GlobeEntity(
                radius: radius,
                configuration: configuration
            )
            print("\tAdd globe:", globeEntity.name)
            content.add(globeEntity)
            self.globeEntity = globeEntity
        } update: { content in
            print("* Update", configuration.globe.name)
            
            // if the globe changed, remove the old entity and add the new entity
            if let oldGlobeEntity = content.entities.first(where: { $0 is GlobeEntity }),
               oldGlobeEntity.name != configuration.globe.name {
                print("Remove", oldGlobeEntity.name)
                content.remove(oldGlobeEntity)
            }
            
            // add the globe if there is none
            if content.entities.first(where: {$0 is GlobeEntity }) == nil,
                let globeEntity {
                print("\tAdd globe:", globeEntity.name)
                content.add(globeEntity)
            }
            globeEntity?.update(configuration: configuration)
        }
        .placementGestures(axZoomIn: axZoomIn, axZoomOut: axZoomOut)
//        .onChange(of: configuration.position) { _, _ in
//            print("Position changed > update globe entity")
//            globeEntity?.update(configuration: configuration)
//        }
//        .onChange(of: configuration.isPaused) { _, _ in
//            print("isPaused changed > update globe entity")
//            globeEntity?.update(configuration: configuration)
//        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveGlobeView(configuration: .init(globe: Globe.preview))
}
