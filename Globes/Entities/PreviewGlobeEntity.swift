//
//  PreviewGlobeEntity.swift
//  Globes
//
//  Created by Bernhard Jenny on 22/5/2024.
//

import RealityKit
import Foundation

class PreviewGlobeEntity: Entity {
    
    let globeId: Globe.ID
    
    let addHoverEffect: Bool
    
    let roughness: Float = 0.35
    
    /// Clear coat gives the material white reflections
    let clearcoat: Float = 0.15
    
    @MainActor required init() {
        self.globeId = UUID()
        self.addHoverEffect = false
        super.init()
    }
    
    init(globe: Globe, addHoverEffect: Bool = false, radius: Float) async throws {
        self.globeId = globe.id
        self.addHoverEffect = addHoverEffect
        super.init()
        
        let material = try await ResourceLoader.loadMaterial(
            globe: globe,
            loadPreviewTexture: true,
            roughness: roughness,
            clearcoat: clearcoat
        )
        
        let mesh: MeshResource = .generateSphere(radius: radius)
        self.addChild(ModelEntity(mesh: mesh, materials: [material]))
        
        // react to user taps
        self.components.set(InputTargetComponent())
        
        if addHoverEffect {
            self.components.set(HoverEffectComponent())
        }

        self.name = globe.name
    }
}
