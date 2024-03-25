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
        
        /// Maximum diameter of globe when scaled up in meter
        private let maxDiameter: Float = 5
        
        /// Minimum diameter of globe when scaled down in meter
        private let minDiameter: Float = 0.05
        
        /// Globe metadata and texture source name
        var globe: Globe
        
        /// An entity consisting of a mesh, material, etc.
        var globeEntity: GlobeEntity?
        
        /// Opacity of the globe
        var opacity: Float = 1
                
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
        
        /// Minimum scale factor
        var minScale: Float {
            let d = 2 * globe.radius
            return minDiameter / d
        }
        
        /// Maximum scale factor
        var maxScale: Float {
            let d = 2 * globe.radius
            return max(1, maxDiameter / d)
        }
        
        init(
            globe: Globe,
            speed: Float = 0,
            isPaused: Bool = false,
            usePreviewTexture: Bool = false,
            enableGestures: Bool = false,
            addHoverEffect: Bool = false
        ) {
            self.globe = globe
            self.globeEntity = nil
            self.speed = speed
            self.isRotationPaused = isPaused
            self.usePreviewTexture = usePreviewTexture
            self.enableGestures = enableGestures
            self.addHoverEffect = addHoverEffect
        }
    }
}
