//
//  GlobeEntity.swift
//  Globes
//
//  Created by Bernhard Jenny on 13/3/2024.
//

import RealityKit
import SwiftUI

/// Globe entity with a model child consisting of a mesh and a material, plus optional `InputTargetComponent` and `CollisionComponent` components.
/// Gestures mutate the transform of this parent entity, while the optional automatic rotation mutates the transform of the child entity.
class GlobeEntity: Entity {
    
    /// Duration of animations of the transform of this entity in seconds.
    private let transformAnimationDuration: Double = 1
    
    /// Child model entity
    private var modelEntity: Entity? { children.first(where: { $0 is ModelEntity }) }
    
    @MainActor required init() {
        super.init()
    }
    
    /// Globe entity
    /// - Parameters:
    ///   - globe: Globe settings.
    ///   - loadPreviewTexture: If true, a small image is loaded from the assets; if false, a large image is loaded from the app bundle.
    ///   - enableGestures: If true gestures for positioning and scaling the globe are added.
    ///   - castsShadow: If true, the globe casts a grounding shadow.
    ///   - roughness: A small roughness results in shiny reflection and large roughness results in matte appearance. Between 0 and 1.
    ///   - clearcoat: Simulate a clear transparent coating between 0 (none) and 1 (max).
    ///   - radius: A radius that replaces `globe.radius`.
    init(
        globe: Globe,
        loadPreviewTexture: Bool,
        enableGestures: Bool,
        castsShadow: Bool,
        roughness: Float,
        clearcoat: Float,
        radius: Float? = nil
    ) async throws {
        super.init()
        
        let radius = radius ?? globe.radius
        
        let material = try await Self.loadMaterial(globe: globe, loadPreviewTexture: loadPreviewTexture, roughness: roughness, clearcoat: clearcoat)
        let mesh: MeshResource = .generateSphere(radius: radius)
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        
        // Add InputTargetComponent and CollisionComponent to enable gestures
        if enableGestures {
            components.set(InputTargetComponent())
            components.set(CollisionComponent(shapes: [.generateSphere(radius: radius)], mode: .trigger))
        }
        
        modelEntity.components.set(GroundingShadowComponent(castsShadow: castsShadow))

        self.addChild(modelEntity)
        self.name = globe.name
    }
    
    @MainActor
    func update(configuration: GlobeConfiguration) {
        // Set the speed of the automatic rotation
        if let modelEntity {
            let currentSpeed = configuration.currentSpeed(scale: meanScale)
            if var rotation: RotationComponent = modelEntity.components[RotationComponent.self] {
                if configuration.adjustRotationSpeedToSize {
                    rotation.speed = currentSpeed
                    modelEntity.components[RotationComponent.self] = rotation
                }
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
    
    /// The orientation of the model child entity.
    var modelOrientation: simd_quatf? {
        get { modelEntity?.orientation }
        set {
            if let rotation = newValue {
                modelEntity?.orientation = rotation
            }
        }
    }
    
    /// The  mean scale factor of this entity.
    @MainActor
    var meanScale: Float { scale.sum() / 3 }
    
    /// Load the globe material, including a texture.
    static private func loadMaterial(globe: Globe, loadPreviewTexture: Bool, roughness: Float, clearcoat: Float) async throws -> RealityKit.Material {
        
        assert(roughness >= 0 && roughness <= 1, "Roughness out of bounds.")
        assert(clearcoat >= 0 && clearcoat <= 1, "Clearcoat out of bounds.")
        
        // highest possible quality for mipmap texture sampling
        let samplerDescription = MTLSamplerDescriptor()
        samplerDescription.maxAnisotropy = 16 // 16 is maximum number of samples for anisotropic filtering (default is 1)
        samplerDescription.minFilter = MTLSamplerMinMagFilter.linear // linear filtering (instead of nearest) when texture pixels are larger than rendered pixels
        samplerDescription.magFilter = MTLSamplerMinMagFilter.linear // linear filtering (instead of nearest) when texture pixels are smaller than rendered pixels
        samplerDescription.mipFilter = MTLSamplerMipFilter.linear // linear interpolation between mipmap levels
        
        let textureResource = try await loadTexture(globe: globe, loadPreviewTexture: loadPreviewTexture)
        let textureSampler = MaterialParameters.Texture.Sampler(samplerDescription)
        
        var material = PhysicallyBasedMaterial()
        material.baseColor.texture = MaterialParameters.Texture(textureResource, sampler: textureSampler)
        
        // small roughness results in shiny reflection, large roughness results in matte appearance
        material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: roughness)

        // simulate clear transparent coating between 0 (none) and 1
        material.clearcoat = .init(floatLiteral: clearcoat)

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
            var url = Bundle.main.url(forResource: globe.texture, withExtension: "jpg")
            if url == nil {
                url = Bundle.main.url(forResource: globe.texture, withExtension: "heic")
            }
            guard let url else {
                fatalError("Cannot find \(globe.texture) with JPEG or HEIC format in the app bundle.")
            }
            return try await TextureResource(contentsOf: url, options: textureOptions)
        }
#endif
    }
}
