//
//  GlobeConfiguration.swift
//  Globes
//
//  Created by Bernhard Jenny on 14/3/2024.
//

import SwiftUI

/// Configuration information for globe entities.
struct GlobeConfiguration: Equatable {

    var isLoading = false
    
    /// If true, a view is attached to the globe
    var showAttachment = false
    
    // MARK: - Size
    
    /// Maximum diameter of globe when scaled up in meter
    private let maxDiameter: Float = 5
    
    /// Minimum diameter of globe when scaled down in meter
    private let minDiameter: Float = 0.05
    
    let radius: Float
    
    // MARK: - Position
    
    /// Position the globe relative to the camera position such that closest point on the globe is at `distanceToGlobe`.
    /// The direction between the camera and the globe is 30 degrees below the horizon.
    /// - Parameter distanceToGlobe: Distance to globe
    func positionRelativeToCamera(distanceToGlobe: Float) -> SIMD3<Float> {
        guard let cameraViewDirection = CameraTracker.shared.viewDirection,
              let cameraPosition = CameraTracker.shared.position else {
            return SIMD3(0, 1, 0)
        }
        
        // oblique distance between camera and globe center
        let d = (radius + distanceToGlobe)
        
        // position relative to camera position
        var position = cameraViewDirection * d + cameraPosition

        // vertically shift the globe down
        // the center of the globe is at this angle below the horizon
        let alpha: Float = 30 / 180 * .pi
        position.y -= sin(alpha) * d
        
        return position
    }
    
    // MARK: - Scale
    
    /// Minimum scale factor
    var minScale: Float {
        let d = 2 * radius
        return minDiameter / d
    }
    
    /// Maximum scale factor
    var maxScale: Float {
        let d = 2 * radius
        return max(1, maxDiameter / d)
    }
    
    // MARK: - Rotation
    
    /// Speed of rotation used
    var rotationSpeed: Float
    
    /// Duration in seconds for full rotation of a spinning globe.
    static private let rotationDuration: Float = 120
    
    /// Angular speed in radians per second for a spinning globe.
    static let defaultRotationSpeed: Float = 2 * .pi / rotationDuration
    
    /// Angular speed in radians per second for a small preview globe.
    static let defaultRotationSpeedForPreviewGlobes: Float = defaultRotationSpeed * 5
    
    /// If true, the angular rotation speed is proportional to the size of a globe, taking the current scale factor (if greater than 1) into account.
    var adjustRotationSpeedToSize: Bool
    
    /// Pause rotation by `RotationSystem`
    var isRotationPaused: Bool
    
    /// Current speed of rotation taking `isRotationPaused` flag into account.
    var currentRotationSpeed: Float {
        isRotationPaused ? 0 : rotationSpeed
    }
    
    /// Current angular speed of rotation taking `isRotationPaused` flag into account.
    ///
    /// If `adjustRotationSpeedToSize` is true, the angular speed is inversely proportional to the radius of the globe and also inversely proportional to the passed `scale` factor.
    /// If `adjustRotationSpeedToSize` is false, `currentSpeed` is returned.
    /// - Parameter scale: The current scale of the globe. Values smaller than 1 are ignored.
    /// - Returns: Angular speed.
    func currentRotationSpeed(scale: Float) -> Float {
        if adjustRotationSpeedToSize {
            let currentRadius = max(1, scale) * radius
            return currentRotationSpeed / currentRadius
        } else {
            return currentRotationSpeed
        }
    }
    
    // MARK: - Initializer
    
    init(
        radius: Float,
        speed: Float = 0,
        adjustRotationSpeedToSize: Bool = true,
        isRotationPaused: Bool = false
    ) {
        self.radius = radius
        self.rotationSpeed = speed
        self.adjustRotationSpeedToSize = adjustRotationSpeedToSize
        self.isRotationPaused = isRotationPaused
    }
}
