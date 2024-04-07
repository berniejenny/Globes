//
//  GlobeEntity.swift
//  Globes
//
//  Created by Bernhard Jenny on 13/3/2024.
//

import RealityKit
import SwiftUI

/// Globe entity with a model child consisting of a mesh and a material, plus optional `InputTargetComponent`, `CollisionComponent`, and `HoverEffectComponent` components.
class GlobeEntity: Entity {
   
    private let transformAnimationDuration: Double = 1
    
    private(set) var modelEntity = Entity()
    
    @MainActor required init() {
        super.init()
    }
    
    init(
        globe: Globe,
        loadPreviewTexture: Bool = false,
        enableGestures: Bool = true,
        radius: Float? = nil
    ) async throws {
        super.init()
        
        let radius = radius ?? globe.radius
        
        let material = try await Self.loadMaterial(globe: globe, loadPreviewTexture: loadPreviewTexture)
        let mesh: MeshResource = .generateSphere(radius: radius)
        self.modelEntity = ModelEntity(mesh: mesh, materials: [material])
        
        // Add InputTargetComponent and CollisionComponent to enable gestures
        if enableGestures {
            components.set(InputTargetComponent())
            components.set(CollisionComponent(shapes: [.generateSphere(radius: radius)], mode: .trigger))
        }
        
        self.addChild(modelEntity)
        self.name = globe.name
    }
    
    @MainActor
    func update(configuration: GlobeConfiguration) {
        // Set the speed of the automatic rotation
        if configuration.adjustRotationSpeedToSize {
            let currentSpeed = configuration.currentSpeed(scale: uniformScale)
            if var rotation: RotationComponent = modelEntity.components[RotationComponent.self] {
                rotation.speed = currentSpeed
                modelEntity.components[RotationComponent.self] = rotation
            } else {
                modelEntity.components.set(RotationComponent(speed: currentSpeed))
            }
        }
        
        let transform = Transform(
            scale: SIMD3<Float>(repeating: configuration.scale),
            rotation: configuration.orientation,
            translation: configuration.position
        )
        if configuration.animateTransform {
            move(to: transform, relativeTo: nil, duration: transformAnimationDuration)
        } else {
            move(to: transform, relativeTo: nil)
        }
    }
    
    /// The  mean scale factor of this entity.
    @MainActor
    var uniformScale: Float { scale.sum() / 3 }
    
    /// Load the globe material, including a texture.
    static private func loadMaterial(globe: Globe, loadPreviewTexture: Bool) async throws -> RealityKit.Material {
        let textureResource = try await loadTexture(globe: globe, loadPreviewTexture: loadPreviewTexture)
        
        // unlit material looks nice for small globes in selection view. Drop shadows for the large globe would require a lit material.
        var material = UnlitMaterial()
        material.color = .init(texture: .init(textureResource))
        return material
    }
    
    /// Load a texture resource from the app bundle (for full resolution) or the assets store (for preview globes).
    static private func loadTexture(globe: Globe, loadPreviewTexture: Bool) async throws -> TextureResource {
        let textureOptions = TextureResource.CreateOptions(semantic: .color, mipmapsMode: .allocateAndGenerateAll)
#if targetEnvironment(simulator)
        // The visionOS simulator cannot handle 16k textures, so use the preview texture when running in the simulator.
        return try await TextureResource(named: globe.previewTexture, options: textureOptions)
#else
        if loadPreviewTexture {
            // load texture from assets
            return try await TextureResource(named: globe.previewTexture, options: textureOptions)
        } else {
            // load texture from image file in app bundle
            guard let url = Bundle.main.url(forResource: globe.texture, withExtension: "jpg") else {
                fatalError("Cannot find \(globe.texture).jpg in the app bundle.")
            }
            return try await TextureResource(contentsOf: url, options: textureOptions)
        }
#endif
    }
}
