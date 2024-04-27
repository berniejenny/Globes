//
//  ImmersivePreviewGlobeView.swift
//  Globes
//
//  Created by Bernhard Jenny on 26/3/2024.
//

import os
import RealityKit
import SwiftUI

/// A `RealityView` for rendering small preview globes.
struct ImmersivePreviewGlobeView: View {
    @Environment(ViewModel.self) private var model
    
    /// The globe to show.
    let globe: Globe
    
    /// A hack to override the radius of `globe.radius`.
    let radius: Float
    
    var body: some View {
        let opacity: Float = model.hidePreviewGlobes ? 0 : 1
        
        RealityView { content in
            guard let globeEntity = try? await GlobeEntity(
                globe: globe,
                loadPreviewTexture: true,
                enableGestures: false,
                castsShadow: false,
                roughness: 0.35,
                clearcoat: 0.15,
                radius: radius
            ) else {
                fatalError("The preview for \"\(globe.name)\" by \(globe.author) cannot be created.")
            }
            let rotationSpeed = GlobeConfiguration.defaultRotationSpeedForPreviewGlobes
            globeEntity.components.set(RotationComponent(speed: rotationSpeed))
            globeEntity.components.set(OpacityComponent(opacity: opacity))
            content.add(globeEntity)
        } update: { content in
            let entity = content.entities.first(where: { $0 is GlobeEntity })
            entity?.components.set(OpacityComponent(opacity: opacity))
        }
    }
}

#if DEBUG
#Preview(immersionStyle: .mixed) {
    ImmersivePreviewGlobeView(globe: Globe.preview, radius: 0.05)
        .environment(ViewModel.preview)
}
#endif
