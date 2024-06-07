//
//  PanoramaEntity.swift
//  Globes
//
//  Created by Bernhard Jenny on 7/5/2024.
//

import RealityKit
import SwiftUI

class PanoramaEntity: Entity {
   
    private let radius: Float = 10
    
    @MainActor required init() {
        super.init()
    }
    
    init(globe: Globe) async throws {
        super.init()
        
        /*
         The CollisionComponent, which is needed for gesture handling, cannot be hit from the inside.
         https://forums.developer.apple.com/forums/thread/747109?answerId=780780022#780780022
         (Inside-out coordinates are needed for inverting the texture coordinates to apply the texture
         on the inside of the sphere.) Therefore, a child CollisionBox entity with
         InputTargetComponents and the CollisionComponents is added to the parent entity (which is `self`).
         */
        self.addChild(CollisionBox(size: radius * 2))
        
        // sphere with inward pointing texture coordinates
        let inwardSphereEntity = Entity()
        inwardSphereEntity.name = "Sphere with inward texture"
        self.addChild(inwardSphereEntity)
        
        // physically based rendering material with mipmap with dark appearance needing image based lighting
        let material = try await ResourceLoader.loadMaterial(globe: globe, loadPreviewTexture: false, roughness: nil, clearcoat: nil)
        
        // attach the material to the sphere.
        inwardSphereEntity.components.set(
            ModelComponent(
                mesh: .generateSphere(radius: radius),
                materials: [material]
            )
        )
        // texture image points inward at the viewer.
        inwardSphereEntity.scale *= .init(x: -1, y: 1, z: 1)
        
        // rotate by 90 degrees: texture coordinate u = 0 is aligned with the x-axis, and u = 0 is the anti-meridian
        self.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0))
        self.name = globe.name + " panorama"
    }
}
