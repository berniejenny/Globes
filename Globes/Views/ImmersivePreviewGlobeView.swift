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
    var globe: Globe
    
    /// The globe entity
    @State var globeEntity: Entity? = nil
    
    /// IBL entity if virtual light is used.
    @State private var imageBasedLightSourceEntity: ImageBasedLightSourceEntity? = nil
    
    var rotate = true
    
    var addHoverEffect = false
        
    /// Override the radius of `globe.radius`.
    let radius: Float
    
    var body: some View {
        RealityView (make: {
            content in
            globeEntity = try? await PreviewGlobeEntity(
                globe: globe,
                addHoverEffect: addHoverEffect,
                radius: radius
            )
            guard let globeEntity else {
                Logger().error("Cannot load preview for \(globe.name)")
                return
            }
            content.add(globeEntity)
            
            applyRotation()
            
            // image based lighting
            self.imageBasedLightSourceEntity = await loadImageBaseLightSourceEntity()
            applyImageBasedLighting()
        }, update: { content in
            // replace the globe entity if it changed
            if let globeEntity,
               let oldGlobeEntity = content.entities.first(where: { $0 is PreviewGlobeEntity }) {
                if oldGlobeEntity != globeEntity {
                    content.remove(oldGlobeEntity)
                    content.add(globeEntity)
                }
            }
            
            applyRotation()
            applyImageBasedLighting()
        })
        .onChange(of: model.lighting) {
            // load another image based lighting texture
            Task { @MainActor in
                imageBasedLightSourceEntity = await loadImageBaseLightSourceEntity()
            }
        }
        .onChange(of: model.isShowingPanorama) {
            // might have to change image based lighting texture, as natural lighting is not available inside a panorama
            Task { @MainActor in
                imageBasedLightSourceEntity = await loadImageBaseLightSourceEntity()
            }
        }
        .onChange(of: globe.id) {
            // the globe changed, create a new entity
            Task { @MainActor in
                globeEntity = try? await PreviewGlobeEntity(globe: globe, radius: radius)
            }
        }
    }
    
    @MainActor
    private func loadImageBaseLightSourceEntity() async -> ImageBasedLightSourceEntity? {
        // natural lighting is not available when a panorama is visible
        var lighting = model.lighting
        if model.isShowingPanorama && model.lighting == .natural {
            lighting = Lighting.even
        }
        
        return await ImageBasedLightSourceEntity(
            texture: lighting.imageBasedLightingTexture,
            intensity: model.imageBasedLightIntensity)
    }
    
    private func applyRotation() {
        guard let globeEntity else { return }
        
        if rotate {
            if globeEntity.components.has(RotationComponent.self) { return }
            let rotationSpeed = GlobeConfiguration.defaultRotationSpeedForPreviewGlobes
            let rotationComponent = RotationComponent(speed: rotationSpeed)
            globeEntity.components.set(rotationComponent)
        } else {
            globeEntity.components.remove(RotationComponent.self)
        }
    }
    
    private func applyImageBasedLighting() {
        guard let globeEntity else { return }
        
        if let imageBasedLightSourceEntity {
            globeEntity.parent?.addChild(imageBasedLightSourceEntity)
            let receiver = ImageBasedLightReceiverComponent(imageBasedLight: imageBasedLightSourceEntity)
            globeEntity.components.set(receiver)
        } else {
            if let oldIBLEntity = globeEntity.parent?.children.first(where: { $0 is ImageBasedLightSourceEntity }) {
                globeEntity.parent?.removeChild(oldIBLEntity)
            }
            globeEntity.components.remove(ImageBasedLightReceiverComponent.self)
        }
    }
}

#if DEBUG
#Preview(immersionStyle: .mixed) {
    ImmersivePreviewGlobeView(globe: Globe.preview, rotate: true, radius: 0.05)
        .environment(ViewModel.preview)
}
#endif
