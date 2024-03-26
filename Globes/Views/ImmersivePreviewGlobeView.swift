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
    @Bindable var configuration: GlobeConfiguration
    
    /// A hack to override the radius of `configuration`.
    let radius: Float
   
    var body: some View {
        RealityView { content in
            guard let globeEntity = try? await GlobeEntity(radius: radius, configuration: configuration) else {
                fatalError("The preview for \"\(configuration.globe.name)\" cannot be created.")
            }
            content.add(globeEntity)
            globeEntity.components.set(RotationComponent(speed: configuration.currentSpeed))
            globeEntity.components.set(OpacityComponent(opacity: configuration.opacity))
        }
    }
}

#if DEBUG
#Preview(immersionStyle: .mixed) {
    ImmersivePreviewGlobeView(configuration: .init(globe: Globe.preview), radius: 0.05)
        .environment(ViewModel.preview)
}
#endif
