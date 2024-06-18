//
//  GlobeEntity.swift
//  Globes
//
//  Created by Bernhard Jenny on 13/3/2024.
//

import os
import RealityKit
import SwiftUI

/// Globe entity with a model child consisting of a mesh and a material, plus  `InputTargetComponent`, `CollisionComponent` and `PhysicsBodyComponent` components.
/// Gestures mutate the transform of this parent entity, while the optional automatic rotation mutates the transform of the child entity.
class GlobeEntity: Entity {
    
    /// Child model entity
    var modelEntity: Entity? { children.first(where: { $0 is ModelEntity }) }
    
    let globeId: Globe.ID
    
    /// Small roughness results in shiny reflection, large roughness results in matte appearance
    let roughness: Float = 0.4
    
    /// Simulate clear transparent coating between 0 (none) and 1
    let clearcoat: Float = 0.05
    
    /// Duration of animations of scale, orientation and position in seconds.
    static let transformAnimationDuration: Double = 2
        
    /// Controller for stopping animated transformations.
    var animationPlaybackController: AnimationPlaybackController? = nil
    
    @MainActor required init() {
        self.globeId = UUID()
        super.init()
    }
    
    /// Globe entity
    /// - Parameters:
    ///   - globe: Globe settings.
    init(globe: Globe) async throws {
        self.globeId = globe.id
        super.init()
                
        let material = try await ResourceLoader.loadMaterial(
            globe: globe,
            loadPreviewTexture: false,
            roughness: roughness,
            clearcoat: clearcoat
        )
        try Task.checkCancellation() // https://developer.apple.com/wwdc21/10134?time=723
        
        let mesh: MeshResource = .generateSphere(radius: globe.radius)
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        modelEntity.name = "Sphere"
        modelEntity.components.set(GroundingShadowComponent(castsShadow: true))
        
        // Add InputTargetComponent and CollisionComponent to enable gestures and physics
        components.set(InputTargetComponent())
        components.set(CollisionComponent(shapes: [.generateSphere(radius: globe.radius)], mode: .trigger))
        
        components.set(PhysicsBodyComponent(massProperties: .default, material: .default, mode: .dynamic))

        self.addChild(modelEntity)
        self.name = globe.name
    }
    
    @MainActor
    /// Set the speed of the automatic rotation
    /// - Parameter configuration: Configuration with rotation speed information.
    func updateRotation(configuration: GlobeConfiguration) {
        if let modelEntity {
            if var rotationComponent: RotationComponent = modelEntity.components[RotationComponent.self] {
                rotationComponent.speed = configuration.currentRotationSpeed
                rotationComponent.globeRadius = configuration.globe.radius
                modelEntity.components[RotationComponent.self] = rotationComponent
            } else {
                let rotationComponent = RotationComponent(
                    speed: configuration.currentRotationSpeed,
                    globeRadius: configuration.globe.radius
                )
                modelEntity.components.set(rotationComponent)
            }
        }        
    }
    
    /// Apply animated transformation. All values in global space. Stops any current animation and updates `self.animationPlaybackController`.
    /// - Parameters:
    ///   - scale: New scale. If nil, scale is not changed.
    ///   - orientation: New orientation. If nil, orientation is not changed.
    ///   - position: New position. If nil, position is not changed.
    ///   - duration: Duration of the animation.
    func animateTransform(
        scale: Float? = nil,
        orientation: simd_quatf? = nil,
        position: SIMD3<Float>? = nil,
        duration: Double = 2
    ) {
        if let scale, abs(scale) < 0.000001 {
            Logger().warning("Animating the scale of an entity to 0 will cause a subsequent inverse of the entity's transform to return NaN values.")
        }
        let scale = scale == nil ? self.scale : [scale!, scale!, scale!]
        let orientation = orientation ?? self.orientation
        let position = position ?? self.position
        let transform = Transform(
            scale: scale,
            rotation: orientation,
            translation: position
        )
        animationPlaybackController?.stop()
        animationPlaybackController = move(to: transform, relativeTo: nil, duration: duration)
        if animationPlaybackController?.isPlaying == false {
            Logger().warning("move(to: relativeTo: duration:) animation not playing for '\(self.name)'.")
            self.transform = transform
        }
    }
    
    /// Returns true if the globe axis is vertically oriented.
    var isNorthOriented: Bool {
        let eps: Float = 0.000001
        let axis = orientation.axis
        if !axis.x.isFinite || !axis.y.isFinite || !axis.z.isFinite {
            return true
        }
        return abs(axis.x) < eps && abs(abs(axis.y) - 1) < eps && abs(axis.z) < eps
    }
    
    /// North-orient the globe.
    /// - Parameter radius: The unscaled radius of the globe, needed for computing the duration of the animation. If nil a default duration is used for the animation..
    func orientToNorth(radius: Float? = nil) {
        let orientation = Self.orientToNorth(orientation: self.orientation)
        let duration = animationDuration(for: orientation, radius: radius)
        animateTransform(orientation: orientation, duration: duration)
    }
    
    /// Rotate an orientation quaternion, such that it is north-oriented.
    /// - Parameter orientation: The quaternion to orient.
    /// - Returns: A new quaternion.
    static func orientToNorth(orientation: simd_quatf) -> simd_quatf {
        // The up vector in the world space (y-axis)
        let worldUp = simd_float3(0, 1, 0)
        
        // Rotate the world up vector by the quaternion
        let localUp = orientation.act(worldUp)
        
        // Compute the axis to rotate around to align localUp with the world up vector
        let rotationAxis = normalize(simd_cross(localUp, worldUp))

        // Compute the angle between localUp and the world up vector
        let dotProduct = simd_dot(localUp, worldUp)
        let angle = acos(dotProduct)

        // Create the quaternion that represents the rotation needed to align localUp with the world up vector
        let alignmentQuat = simd_quatf(angle: angle, axis: rotationAxis)
        
        // Apply the alignment quaternion to the original quaternion to remove the roll component
        return alignmentQuat * orientation
    }
    
    /// Rotates the globe such that a given point on the globe faces the camera.
    /// - Parameters:
    ///   - location: The point on the globe that is to face the camera relative to the center of the globe.
    ///   - radius: The unscaled radius of the globe, needed for computing the duration of the animation. If nil a default duration is used for the animation.
    func rotate(to location: SIMD3<Float>, radius: Float? = nil) {
        if let cameraPosition = CameraTracker.shared.position {
            // Unary vector in global space from the globe center to the camera.
            // This vector is pointing from the globe center toward the target position on the globe.
            let v = normalize(cameraPosition - position(relativeTo: nil))

            // rotate the point to the target position
            let orientation = simd_quatf(from: normalize(location), to: v)
            
            let duration = animationDuration(for: orientation, radius: radius)
            animateTransform(orientation: orientation, duration: duration)
        }
    }
    
    /// Returns a duration in seconds for animating a transformation. Takes into account the size of the globe and the angular distance of the transformation.
    /// - Parameters:
    ///   - transformation: The transformation.
    ///   - radius: The unscaled radius of the globe. If nil, a default duration is returned.
    /// - Returns: Duration in seconds.
    func animationDuration(for transformation: simd_quatf, radius: Float?) -> Double {
        var duration = Self.transformAnimationDuration
        guard let radius else { return duration }
        // scale duration with current size of the globe if the scaled radius is greater than 1 meter
        // radius of 1 m -> 1, max radius -> max radius
        let scaledRadius = radius * meanScale
        let sizeScale = max(1, scaledRadius)
        duration *= Double(sizeScale)
        
        // scale duration with angle: 0° -> 0, 180° -> 2
        let angle = (transformation.conjugate * orientation).angle
        duration *= Double(angle / .pi * 2)
        
        return max(0.2, duration)
    }
    
    /// Returns true if the scaled size of the globe is close to the original size.
    /// - Parameters:
    ///   - radius: Radius of the globe in meter.
    ///   - tolerance: Tolerance in meter, default is 3 mm.
    /// - Returns: True if the size is close to the original.
    func isAtOriginalSize(radius: Float, tolerance: Float = 0.003) -> Bool {
        let eps = tolerance / radius
        return abs(scale.x - 1) < eps && abs(scale.y - 1) < eps && abs(scale.z - 1) < eps
    }
    
    /// Changes the scale of the globe and moves the globe along a line connecting the camera and the center of the globe,
    /// such that the globe section facing the camera remains at a constant distance.
    /// - Parameters:
    ///   - newScale: The new scale of the globe.
    ///   - oldScale: The current scale of the globe.
    ///   - oldPosition: The current position of the globe.
    ///   - cameraPosition: The camera position. If nil, the current camera position is retrieved.
    ///   - radius: Radius of the unscaled globe.
    ///   - duration: Animation duration in seconds.
    func scaleAndAdjustDistanceToCamera(
        newScale: Float,
        oldScale: Float,
        oldPosition: SIMD3<Float>,
        cameraPosition: SIMD3<Float>? = nil,
        radius: Float,
        duration: Double = 0
    ) {
        let cameraPosition = cameraPosition ?? (CameraTracker.shared.position ?? SIMD3(0, 1, 0))
        
        // Compute by how much the globe radius changes.
        let deltaRadius = (newScale - oldScale) * radius
        
        // The unary direction vector from the globe to the camera.
        let globeCameraDirection = normalize(cameraPosition - oldPosition)
        
        // Move the globe center along that direction.
        let position = oldPosition - globeCameraDirection * deltaRadius
        if duration > 0 {
            animateTransform(scale: newScale, position: position, duration: duration)
        } else {
            self.scale = [newScale, newScale, newScale]
            self.position = position
        }
    }
    
    /// Changes the scale of the globe and moves the globe along a line connecting the camera and the center of the globe,
    /// such that the globe section facing the camera remains at a constant distance.
    /// - Parameters:
    ///   - newScale: The new scale of the globe.
    ///   - radius: Radius of the unscaled globe.
    ///   - duration: Animation duration in seconds.
    func scaleAndAdjustDistanceToCamera(
        newScale: Float,
        radius: Float,
        duration: Double = 0
    ) {
        self.scaleAndAdjustDistanceToCamera(
            newScale: newScale,
            oldScale: meanScale,
            oldPosition: position,
            radius: radius,
            duration: duration
        )
    }
    
    /// Returns the distance between the closest point of globe surface to the camera and the camera position.
    /// - Parameter radius: Radius of the globe in meter.
    /// - Returns: Distance in meter.
    func distanceToCamera(radius: Float) throws -> Float  {
        guard let cameraPosition = CameraTracker.shared.position else {
            throw error("The camera position is unknown.")
        }
        let globeCenter = position(relativeTo: nil)
        return distance(cameraPosition, globeCenter) - radius
    }
    
    /// Move a globe toward the camera along a straight line.
    /// - Parameters:
    ///   - distance: The target distance between the camera and the closest point on the globe.
    ///   - radius: The radius of the globe.
    ///   - duration: Duration of the animation.
    func moveTowardCamera(distance: Float, radius: Float, duration: Double = 0) {
        guard let cameraPosition = CameraTracker.shared.position else { return }
        let globeCenter = position(relativeTo: nil)
        let v = normalize(globeCenter - cameraPosition)
        let newGlobeCenter = cameraPosition + v * (distance + radius)
        animateTransform(position: newGlobeCenter, duration: duration)
    }
    
    /// The  mean scale factor of this entity relative to the world space.
    @MainActor
    var meanScale: Float { scale(relativeTo: nil).sum() / 3 }
}
