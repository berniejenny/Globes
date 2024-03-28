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
    
    init(radius: Float? = nil, configuration: GlobeConfiguration) async throws {
        super.init()
        try await addGlobe(radius: radius, configuration: configuration)
    }
    
    func addGlobe(radius: Float? = nil, configuration: GlobeConfiguration) async throws {
        let material = await loadMaterial(configuration: configuration)
        let radius = radius ?? configuration.globe.radius
        let mesh: MeshResource = .generateSphere(radius: radius)
        modelEntity = ModelEntity(mesh: mesh, materials: [material])
        
        // Add InputTargetComponent and CollisionComponent to enable gestures, which is also needed for the hover effect
        if configuration.enableGestures {
            components.set(InputTargetComponent())
            components.set(CollisionComponent(shapes: [.generateSphere(radius: radius)], mode: .trigger))
        }
        if configuration.addHoverEffect {
            modelEntity.components.set(HoverEffectComponent())
        }
        
        self.addChild(modelEntity)
        self.name = configuration.globe.name
        
        update(configuration: configuration)
    }
    
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
        
        // adjust the opacity
        modelEntity.components.set(OpacityComponent(opacity: configuration.opacity))
    }
    
    /// The  uniform scale factor. Read and write access is observed by SwiftUI (unlike changes to normal entity properties).
    var uniformScale: Float {
        // modelEntity is not @Observed, so programmatically inform the Observation framework about access and mutation.
        // https://developer.apple.com/wwdc23/10149?time=558
        get {
            access(keyPath: \.uniformScale)
            return scale.sum() / 3
        }
        set {
            withMutation(keyPath: \.uniformScale) {
                scale = SIMD3<Float>(repeating: newValue)
            }
        }
    }
    
    /// Changes the scale of the globe and move the globe along a line connecting the camera and the center of the globe,
    /// such that the globe section facing the camera remains at a constant distance.
    /// - Parameters:
    ///   - newScale: The new scale of the globe.
    ///   - oldScale: The current scale of the globe. If nil, `uniformScale` is used.
    ///   - oldPosition: The current position of the globe. If nil, `position` is used.
    ///   - cameraPosition: The camera position. If nil, the current camera position is retrieved.
    ///   - globeRadius: The radius of the globe in meter.
    func scaleAndAdjustDistanceToCamera(
        newScale: Float,
        oldScale: Float? = nil,
        oldPosition: SIMD3<Float>? = nil,
        cameraPosition: SIMD3<Float>? = nil,
        globeRadius: Float
    ) {
        let oldScale = oldScale ?? uniformScale
        let oldPosition = oldPosition ?? position
        let cameraPosition = cameraPosition ?? CameraTracker.shared.position
        
        // Compute by how much the globe radius changes.
        let deltaRadius = (newScale - oldScale) * globeRadius

        // The unary direction vector from the globe to the camera.
        let globeCameraDirection = normalize(cameraPosition - oldPosition)
        
        // Move the globe center along that direction.
        position = oldPosition - globeCameraDirection * deltaRadius
        
        // Change `uniformScale` instead of `scale`, such that SwiftUI is informed and updates.
        uniformScale = newScale
    }
    
    func rotate(by rotation: simd_quatf) {
        globeOrientation *= rotation
    }
    
    /// Reset the orientation of the entity to identity quaternion
    func resetRotation() {
        globeOrientation = simd_quatf(real: 1, imag: SIMD3<Float>(0, 0, 0))
    }
    
    /// The  orientation of the globe. Read and write access is observed by SwiftUI (unlike changes to normal entity properties).
    /// This changes the orientation of this parent entity, and not the orientation of its child model entity, which has an optional rotation animation. 
    var globeOrientation: simd_quatf {
        // globeOrientation is not @Observed, so programmatically inform the Observation framework about access and mutation.
        // https://developer.apple.com/wwdc23/10149?time=558
        get {
            access(keyPath: \.globeOrientation)
            return orientation
        }
        set {
            withMutation(keyPath: \.globeOrientation) {
                orientation = newValue
            }
        }
    }
    
    /// Load texture material from app bundle (for full resolution) or assets store (for preview globes).
    private func loadMaterial(configuration: GlobeConfiguration) async -> RealityKit.Material {
        let globe = configuration.globe
        
        // 16k textures cannot be loaded from the assets catalogue, so load preview images from assets and full resolution image from the app bundle
        do {
            let textureResource = try await loadTexture(configuration: configuration)
            
            // unlit material looks nice for small globes in selection view. Drop shadows for the large globe would require a lit material.
            var material = UnlitMaterial()
            material.color = .init(texture: .init(textureResource))
            return material
        } catch {
            let textureName = configuration.usePreviewTexture ? globe.previewTexture : globe.texture
            fatalError("Cannot load \(textureName) from the app bundle. \(error.localizedDescription)")
        }
    }
    
    /// Load a texture from assets, the app bundle or and URL
    /// - Parameter configuration: Globe configuration
    /// - Returns: A texture resource.
    private func loadTexture(configuration: GlobeConfiguration) async throws -> TextureResource {
        let globe = configuration.globe
        let textureOptions = TextureResource.CreateOptions(semantic: .color, mipmapsMode: .allocateAndGenerateAll)
       
#if targetEnvironment(simulator)
        // The visionOS simulator cannot handle 16k textures, so use the preview texture when running in the simulator.
        return try await TextureResource(named: globe.previewTexture, options: textureOptions)
#else
        if configuration.usePreviewTexture {
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
