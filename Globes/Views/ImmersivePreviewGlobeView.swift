//
//  ImmersivePreviewGlobeView.swift
//  Globes
//
//  Created by Bernhard Jenny on 26/3/2024.
//

import os
import RealityKit
import SwiftUI

/// Immersive globe for rendering small preview globes that do not change over time.
struct ImmersivePreviewGlobeView: View {
    @Environment(ViewModel.self) private var model
    
    /// The globe to show.
    let globe: Globe
    
    /// The opacity of the preview globe
    var opacity: Float
    
    /// A hack to override the radius of `globe.radius`.
    let radius: Float
   
    var body: some View {
        RealityView { content in
            let configuration = GlobeConfiguration(
                globe: globe,
                usePreviewTexture: true,
                addHoverEffect: false // hover effect on the globe would be confusing, because the background changes color when the globe is hovered.
            )
            guard let globeEntity = try? await GlobeEntity(radius: radius, configuration: configuration) else {
                fatalError("The preview for \"\(globe.name)\" cannot be created.")
            }
            content.add(globeEntity)
            globeEntity.components.set(RotationComponent(speed: GlobeConfiguration.defaultRotationSpeedForPreviewGlobes))
            globeEntity.components.set(OpacityComponent(opacity: opacity))
        } update: { content in
            let entity = content.entities.first(where: { $0 is GlobeEntity })
            entity?.components.set(OpacityComponent(opacity: opacity))
        }
    }
}

#if DEBUG
#Preview(immersionStyle: .mixed) {
    ImmersivePreviewGlobeView(globe: Globe.preview, opacity: 1, radius: 0.05)
        .environment(ViewModel.preview)
}
#endif
