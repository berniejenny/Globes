//
//  ImmersivePreviewGlobeView.swift
//  Globes
//
//  Created by Bernhard Jenny on 26/3/2024.
//

import os
import RealityKit
import SwiftUI

/// A `RealityView` for rendering a small preview globe that fills the available space.
struct ImmersivePreviewGlobeView: View {
    @Environment(ViewModel.self) private var model
    
    /// The globe to show.
    var globe: Globe
    
    /// If true, the globe is rotating
    var rotate = true
    
    /// If true,  a highlight effect is shown when the globe is hovered
    var addHoverEffect = false
    
    /// The globe entity
    @State private var globeEntity: PreviewGlobeEntity? = nil
    
    /// IBL entity if virtual light is used.
    @State private var imageBasedLightSourceEntity: ImageBasedLightSourceEntity? = nil
    
    /// True if the size of this view changed, which requires scaling the globe to fill the view
    @State private var sizeChanged = false
    
    var body: some View {
        GeometryReader3D { geometry in
            RealityView (make: { content in
                if let globeEntity = await createGlobe() {
                    content.add(globeEntity)
                }
                
                let radius = computeRadius(content, geometry)
                scaleTo(radius: radius)
                // store the radius of the globe in scene coordinates
                model.previewRadii[globe.id] = radius
                
                applyRotation()
                
                // image based lighting
                self.imageBasedLightSourceEntity = await loadImageBasedLightSourceEntity()
                applyImageBasedLighting()
            }, update: { content in
                // replace the globe entity if it changed
                if let globeEntity,
                   let oldGlobeEntity = content.entities.first(where: { $0 is PreviewGlobeEntity }) {
                    if oldGlobeEntity.id != globeEntity.id {
                        content.remove(oldGlobeEntity)
                        globeEntity.scale = oldGlobeEntity.scale
                        content.add(globeEntity)
                    }
                }
                
                applyRotation()
                applyImageBasedLighting()
                
                if sizeChanged {
                    let radius = computeRadius(content, geometry)
                    scaleTo(radius: radius)
                    Task { @MainActor in
                        sizeChanged = false
                        // store the radius of the globe in scene coordinates
                        model.previewRadii[globe.id] = radius
                    }
                }
            })
            // store the center of this view such that the globe in immersive space can transition from and to the center
            .onChange(of: geometry.frame(in: .immersiveSpace).center, initial: true) {
                let previewCenter = geometry.frame(in: .immersiveSpace).center
                Task { @MainActor in
                    model.previewCenters[globe.id] = previewCenter
                }
            }
            // store the dynamic scale factor of this view such that the globe transitioning from and to this view has the same size as the preview globe
            .onChange(of: geometry.transform(in: .immersiveSpace), initial: true) {
                if let transform = geometry.transform(in: .immersiveSpace) {
                    let scale = Float(transform.scale.vector.sum() / 3)
                    Task { @MainActor in
                        model.previewScales[globe.id] = scale
                    }
                }
            }
            .onChange(of: geometry.size) {
                Task { @MainActor in
                    sizeChanged = true
                }
            }
            .onChange(of: globe.id) {
                // the globe changed, create a new entity
                Task { @MainActor in
                    await createGlobe()
                }
            }
            .onChange(of: model.lighting) {
                // load another image based lighting texture
                Task { @MainActor in
                    imageBasedLightSourceEntity = await loadImageBasedLightSourceEntity()
                }
            }
            .onChange(of: model.isShowingPanorama) {
                // might have to change image based lighting texture, as natural lighting is not available inside a panorama
                Task { @MainActor in
                    imageBasedLightSourceEntity = await loadImageBasedLightSourceEntity()
                }
            }
        }
    }
    
    private func createGlobe() async -> PreviewGlobeEntity? {
        globeEntity = try? await PreviewGlobeEntity(
            globe: globe,
            addHoverEffect: addHoverEffect,
            radius: 1
        )
        guard let globeEntity else {
            Logger().error("Cannot load preview for \(globe.name)")
            return nil
        }
        return globeEntity
    }
   
    /// Computes a radius in scene coordinates [m] for the sphere such that the sphere fills the available view space.
    /// - Parameters:
    ///   - content: Context for coordinate space conversion.
    ///   - geometry: Geometry of the view.
    /// - Returns: A new radius in scene space (i.e. meters).
    private func computeRadius(_ content: RealityViewContent, _ geometry: GeometryProxy3D) -> Float {
        let bounds = content.convert(geometry.frame(in: .local), from: .local, to: .scene)
        let radius = min(bounds.extents.x, bounds.extents.y) / 2
        return radius
    }
    
    @MainActor
    private func scaleTo(radius: Float) {
        let scale = radius
        if let globeEntity,
           globeEntity.scale != [scale, scale, scale] {
            globeEntity.scale = [scale, scale, scale]
        }
    }
    
    @MainActor
    private func loadImageBasedLightSourceEntity() async -> ImageBasedLightSourceEntity? {
        // natural lighting is not available when a panorama is visible
        var lighting = model.lighting
        if model.isShowingPanorama && model.lighting == .natural {
            lighting = Lighting.even
        }
        
        return await ImageBasedLightSourceEntity(
            texture: lighting.imageBasedLightingTexture,
            intensity: model.imageBasedLightIntensity)
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
}

#if DEBUG
#Preview(windowStyle: .automatic) {
    ImmersivePreviewGlobeView(globe: Globe.preview, rotate: true)
        .environment(ViewModel.preview)
}
#endif
