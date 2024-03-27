//
//  GlobeConfiguration.swift
//  Globes
//
//  Created by Bernhard Jenny on 14/3/2024.
//

import SwiftUI

/// Configuration information for globe entities.
@Observable class GlobeConfiguration {
    
    /// Duration in seconds for full rotation of a spinning globe.
    static private let rotationDuration: Float = 120
    
    /// Angular speed in radians per second for a spinning globe.
    static let defaultRotationSpeed: Float = 2 * .pi / rotationDuration
    
    /// Angular speed in radians per second for a small preview globe.
    static let defaultRotationSpeedForPreviewGlobes: Float = defaultRotationSpeed * 5
    
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
    
    /// If true, the angular rotation speed is proportional to the size of a globe, taking the current scale factor (if greater than 1) into account.
    var adjustRotationSpeedToSize: Bool
    
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
    
    /// Current angular speed of rotation taking `isRotationPaused` flag into account.
    ///
    /// If `adjustRotationSpeedToSize` is true, the angular speed is inversely proportional to the radius of the globe and also inversely proportional to the passed `scale` factor.
    /// If `adjustRotationSpeedToSize` is false, `currentSpeed` is returned.
    /// - Parameter scale: The current scale of the globe. Values smaller than 1 are ignored.
    /// - Returns: Angular speed.
    func currentSpeed(scale: Float) -> Float {
        if adjustRotationSpeedToSize {
            let currentRadius = max(1, scale) * globe.radius
            return currentSpeed / currentRadius
        } else {
            return currentSpeed
        }
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
        adjustRotationSpeedToSize: Bool = false,
        isPaused: Bool = false,
        usePreviewTexture: Bool = false,
        enableGestures: Bool = false,
        addHoverEffect: Bool = false
    ) {
        self.globe = globe
        self.globeEntity = nil
        self.speed = speed
        self.adjustRotationSpeedToSize = adjustRotationSpeedToSize
        self.isRotationPaused = isPaused
        self.usePreviewTexture = usePreviewTexture
        self.enableGestures = enableGestures
        self.addHoverEffect = addHoverEffect
    }
}
