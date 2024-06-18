/*
 Modified from the Apple Hello World project
 https://developer.apple.com/documentation/visionos/world

Abstract:
A system and component for rotating globes.
*/

import SwiftUI
import RealityKit

/// Automated rotation of a globe.
/// Globes with a smaller radius rotate faster, and globes with a larger radius rotate slower.
/// Globes with a scale factor greater than 1 rotate slower, and globes with a scale factor smaller than 1 rotate faster.
struct RotationComponent: Component {
    
    /// Angular speed of the rotation of a globe with a radius of one meter in radians per second.
    var speed: Float
    
    /// Axis of rotation
    var axis: SIMD3<Float>
    
    /// Radius of the globe in meter.
    /// Globes with a smaller radius rotate faster, and globes with a larger radius rotate slower.
    var globeRadius: Float
    
    /// Maximum angular speed: full rotation in 2 seconds
    static let maxSpeed: Float = .pi
    
    /// Automated rotation of a globe.
    /// Globes with a smaller radius rotate faster, and globes with a larger radius rotate slower.
    /// Globes with a scale factor greater than 1 rotate slower, and globes with a scale factor smaller than 1 rotate faster.
    /// - Parameters:
    ///   - speed: Angular speed of the rotation of a globe with a radius of one meter in radians per second.
    ///   - axis: Axis of rotation
    ///   - globeRadius: Radius of the globe in meter. Globes with a smaller radius rotate faster, and globes with a larger radius rotate slower.
    init(speed: Float = 1.0, axis: SIMD3<Float> = [0, 1, 0], globeRadius: Float = 1) {
        self.speed = speed
        self.axis = axis
        self.globeRadius = globeRadius
    }
}

/// A system that rotates entities with a rotation component.
struct RotationSystem: System {
    static let query = EntityQuery(where: .has(RotationComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let component: RotationComponent = entity.components[RotationComponent.self] else { continue }
            
            var scale = entity.scale.sum() / 3

#warning("hack: fix needed")
            if let parent = entity.parent {
                scale = parent.scale.sum() / 3
            }
            let scaledSpeed = min(RotationComponent.maxSpeed, component.speed / scale / component.globeRadius)
            
            entity.setOrientation(.init(angle: scaledSpeed * Float(context.deltaTime), axis: component.axis), relativeTo: entity)
        }
    }

}

