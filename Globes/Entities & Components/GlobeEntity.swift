//
//  GlobeEntity.swift
//  Globes
//
//  Created by Bernhard Jenny on 13/3/2024.
//

import RealityKit
import SwiftUI

/// Globe entity with a model child consisting of a mesh and a material, plus optional `InputTargetComponent`, `CollisionComponent`, and `HoverEffectComponent` components.
@Observable class GlobeEntity: Entity {
    private var modelEntity = Entity()
    
    @MainActor required init() {
        super.init()
    }
    
    init(radius: Float? = nil, configuration: Configuration) async {
        super.init()
        let radius = radius ?? configuration.globe.radius
        
        let material = loadMaterial(configuration: configuration)
        let mesh: MeshResource = .generateSphere(radius: radius)
        modelEntity = ModelEntity(mesh: mesh, materials: [material])
        
        // Add InputTargetComponent and CollisionComponent to enable gestures, which is also needed for the hover effect
        if configuration.enableGestures {
            modelEntity.components.set(InputTargetComponent())
            modelEntity.components.set(CollisionComponent(shapes: [.generateSphere(radius: radius)], mode: .trigger))
        }
        if configuration.addHoverEffect {
            modelEntity.components.set(HoverEffectComponent())
        }
     
        self.addChild(modelEntity)
        self.name = configuration.globe.name
        
        update(configuration: configuration)
    }
    
    func update(configuration: Configuration) {
        // Set the speed of the automatic rotation
        if var rotation: RotationComponent = modelEntity.components[RotationComponent.self] {
            rotation.speed = configuration.currentSpeed
            modelEntity.components[RotationComponent.self] = rotation
        } else {
            modelEntity.components.set(RotationComponent(speed: configuration.currentSpeed))
        }
        
        // Scale and position the entire entity.
        move(
            to: Transform(
                scale: SIMD3(repeating: 1),
                rotation: orientation,
                translation: configuration.position),
            relativeTo: parent)
    }
        
    var globePosition: SIMD3<Float> {
        // modelEntity is not @Observed, so programmatically inform the Observation framework about access and mutation.
        // https://developer.apple.com/wwdc23/10149?time=558
        get {
            access(keyPath: \.globePosition)
            return modelEntity.position
        }
        set {
            withMutation(keyPath: \.globePosition) {
                modelEntity.position = newValue
            }
        }
    }
    
    /// The uniform scale of the model entity, which is a child of this entity.
    var globeScale: Float {
        // modelEntity is not @Observed, so programmatically inform the Observation framework about access and mutation.
        // https://developer.apple.com/wwdc23/10149?time=558
        get {
            access(keyPath: \.globeScale)
            return (modelEntity.scale.x + modelEntity.scale.y + modelEntity.scale.z) / 3
        }
        set {
            withMutation(keyPath: \.globeScale) {
                modelEntity.scale = SIMD3<Float>(repeating: newValue)
            }
        }
    }
    
    func rotate(by rotation: simd_quatf) {
        self.modelEntity.orientation *= rotation
    }
    
    /// Load texture material from app bundle (for full resolution) or assets store (for preview globes).
    private func loadMaterial(configuration: Configuration) -> RealityKit.Material {
        let globe = configuration.globe
        
        // 16k textures cannot be loaded from the assets catalogue, so load preview images from assets and full resolution image from the app bundle
        do {
            let textureResource: TextureResource
            let textureOptions = TextureResource.CreateOptions(semantic: .color, mipmapsMode: .allocateAndGenerateAll)
#if targetEnvironment(simulator)
            // The visionOS simulator cannot handle 16k textures, so use the preview texture when running in the simulator.
            textureResource = try TextureResource.load(named: globe.previewTexture, options: textureOptions)
#else
            if configuration.usePreviewTexture {
                textureResource = try TextureResource.load(named: globe.previewTexture, options: textureOptions)
            } else {
                guard let url = Bundle.main.url(forResource: globe.texture, withExtension: "jpg") else {
                    fatalError("Cannot find \(globe.texture).jpg in the app bundle.")
                }
                textureResource = try TextureResource.load(contentsOf: url, options: textureOptions)
            }
#endif
            // unlit material looks nice for small globes in selection view. Drop shadows for the large globe would require a lit material.
            var material = UnlitMaterial()
            material.color = .init(texture: .init(textureResource))
            return material
        } catch {
            let textureName = configuration.usePreviewTexture ? globe.previewTexture : globe.texture
            fatalError("Cannot load \(textureName) from the app bundle. \(error.localizedDescription)")
        }
    }
}
