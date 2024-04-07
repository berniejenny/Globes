//
//  GlobeConfiguration.swift
//  Globes
//
//  Created by Bernhard Jenny on 14/3/2024.
//

import SwiftUI

/// Configuration information for globe entities.
@MainActor
@Observable
class GlobeConfiguration {
    
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
    
    /// Speed of rotation used
    var speed: Float
    
    /// If true, the angular rotation speed is proportional to the size of a globe, taking the current scale factor (if greater than 1) into account.
    var adjustRotationSpeedToSize: Bool
    
    /// Pause rotation by `RotationSystem`
    var isRotationPaused: Bool
    
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
    
    /// Scale of the globe
    var scale: Float = 1
    
    /// Orientation of the globe
    var orientation = northOrientation
    
    /// Orientation to north
    static let northOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)) //simd_quatf(real: 1, imag: SIMD3<Float>(0, 0, 0))
    
    /// Reset to north orientation
    func resetOrientation(animate: Bool) {
        animateTransform = animate
        orientation = Self.northOrientation
    }
    
    /// Returns true if the globe axis is vertically oriented.
    var isNorthOriented: Bool {
        let eps: Float = 0.000001
        let axis = orientation.axis
        if !axis.x.isFinite || !axis.y.isFinite || !axis.z.isFinite {
            return true
        }
        return abs(axis.x) < eps && abs(axis.y) - 1 < eps && abs(axis.z) < eps
    }
    
    /// Position of the center of the globe.
    var position = SIMD3<Float>.zero
    
    /// If true, changes of scale, orientation and position are animated.
    var animateTransform = false
    
    init(
        globe: Globe,
        speed: Float = 0,
        adjustRotationSpeedToSize: Bool = true,
        isPaused: Bool = false
    ) {
        self.globe = globe
        self.globeEntity = nil
        self.speed = speed
        self.adjustRotationSpeedToSize = adjustRotationSpeedToSize
        self.isRotationPaused = isPaused
    }
    
    /// Changes the scale of the globe and moves the globe along a line connecting the camera and the center of the globe,
    /// such that the globe section facing the camera remains at a constant distance.
    /// - Parameters:
    ///   - newScale: The new scale of the globe.
    ///   - oldScale: The current scale of the globe.
    ///   - oldPosition: The current position of the globe.
    ///   - cameraPosition: The camera position. If nil, the current camera position is retrieved.
    ///   - animate: If true, the change in  position and scale is animated.
    func scaleAndAdjustDistanceToCamera(
        newScale: Float,
        oldScale: Float,
        oldPosition: SIMD3<Float>,
        cameraPosition: SIMD3<Float>? = nil,
        animate: Bool = false
    ) {
        let cameraPosition = cameraPosition ?? CameraTracker.shared.position
        
        // Compute by how much the globe radius changes.
        let deltaRadius = (newScale - oldScale) * globe.radius
        
        // The unary direction vector from the globe to the camera.
        let globeCameraDirection = normalize(cameraPosition - oldPosition)
        
        // Move the globe center along that direction.
        position = oldPosition - globeCameraDirection * deltaRadius
        
        scale = newScale
        animateTransform = animate
    }
    
    /// Position the globe such that its closest part is at the same distance as the closest part of the previous globe. The scale of the new globe is set to 1.
    /// - Parameter oldConfiguration: Configuration of the old globe.
    func position(relativeTo oldConfiguration: GlobeConfiguration) {
        // radius of the old globe
        let oldRadius = oldConfiguration.globe.radius
        // scaled radius of the old globe
        let oldScaledRadius = oldRadius * oldConfiguration.scale
        // the new globe (with scale = 1) differs by this factor in size from the old globe
        let relativeOldScale = oldScaledRadius / globe.radius
        scaleAndAdjustDistanceToCamera(
            newScale: 1,
            oldScale: relativeOldScale,
            oldPosition: oldConfiguration.position
        )
    }
    
    /// Position the globe relative to the camera position such that closest part of the globe is at `distanceToGlobe`.
    /// The direction between the camera and the globe is 30 degrees below the horizon.
    /// - Parameter distanceToGlobe: <#distanceToGlobe description#>
    func positionRelativeToCamera(distanceToGlobe: Float) {
        // position the globe at this angle below the horizon
        let alpha: Float = 30 / 180 * .pi
        // oblique distance between camera and globe center
        let d = (globe.radius + distanceToGlobe)
        // center of globe in upward direction
        let y = CameraTracker.shared.position.y - sin(alpha) * d
        // center of globe toward the camera
        let z = -cos(alpha) * d
        position = SIMD3<Float>([0, y, z])
    }
}
