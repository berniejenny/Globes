//
//  GlobeEntity+Configuration.swift
//  Globes
//
//  Created by Bernhard Jenny on 14/3/2024.
//

import SwiftUI

extension GlobeEntity {
    /// Configuration information for globe entities.
    struct Configuration {
        let globe: Globe
        
        var scale: Float = 1
        var rotation: simd_quatf = .init(angle: 0, axis: [0, 1, 0])
        var position: SIMD3<Float> = .zero
        
        /// Speed of rotation used `RotationSystem`
        var speed: Float = 0
        
        /// Pause rotation by `RotationSystem`
        var isPaused: Bool = false
        
        /// If true, `globe.previewTexture` is loaded from assets. If false, `globe.texture` is loaded from the app bundle.
        var usePreviewTexture: Bool = false
        
        /// If true,  an InputTargetComponent and a CollisionComponent are added to the globe entity to enable gestures, which is also needed for the hover effect
        var enableGestures: Bool = false
        
        /// If true, a `HoverEffectComponent` is added to the globe entity.
        var addHoverEffect: Bool = false
        
        /// Current speed of rotation taking `isPaused` flag into account.
        var currentSpeed: Float {
            isPaused ? 0 : speed
        }
    }
}
