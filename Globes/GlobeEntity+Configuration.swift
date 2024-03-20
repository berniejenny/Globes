//
//  GlobeEntity+Configuration.swift
//  Globes
//
//  Created by Bernhard Jenny on 14/3/2024.
//

import SwiftUI

extension GlobeEntity {
    
    /// Configuration information for globe entities.
    @Observable class Configuration {
        var globe: Globe
        
        var globeEntity: GlobeEntity?
        
        var rotation: simd_quatf
        var position: SIMD3<Float>
        
        /// Speed of rotation used `RotationSystem`
        var speed: Float
        
        /// Pause rotation by `RotationSystem`
        var isRotationPaused: Bool
        
        /// If true, `globe.previewTexture` is loaded from assets. If false, `globe.texture` is loaded from the app bundle.
        var usePreviewTexture: Bool
        
        /// If true,  an InputTargetComponent and a CollisionComponent are added to the globe entity to enable gestures, which is also needed for the hover effect
        var enableGestures: Bool
        
        /// If true, a `HoverEffectComponent` is added to the globe entity.
        var addHoverEffect: Bool
        
        /// Current speed of rotation taking `isPaused` flag into account.
        var currentSpeed: Float {
            isRotationPaused ? 0 : speed
        }
        
        init(
            globe: Globe,
            rotation: simd_quatf = .init(angle: 0, axis: [0, 1, 0]),
            position: SIMD3<Float> = .zero,
            speed: Float = 0,
            isPaused: Bool = false,
            usePreviewTexture: Bool = false,
            enableGestures: Bool = false,
            addHoverEffect: Bool = false
        ) {
            self.globe = globe
            self.globeEntity = nil
            self.rotation = rotation
            self.position = position
            self.speed = speed
            self.isRotationPaused = isPaused
            self.usePreviewTexture = usePreviewTexture
            self.enableGestures = enableGestures
            self.addHoverEffect = addHoverEffect
        }
    }
}
