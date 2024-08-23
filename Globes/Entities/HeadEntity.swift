//
//  HeadEntity.swift
//  Globes
//
//  Created by Bernhard Jenny on 23/5/2024.
//

import Foundation
import RealityKit
import Combine

/// An invisible sphere centered on the camera that updates its position periodically.
class HeadEntity: Entity {
    var collisionSubscription: Cancellable?
    /// Radius of head sphere: small enough for visionOS to make close objects temporarily semi-transparent
    private let headRadius: Float = 0.18
    
    /// Width and depth of a stick below the camera
    private let stickWidth: Float = 0.01
    
    /// Height of stick below the head
    private let bodyHeight: Float = 1.3

    /// Repeating timer to update the position of the sphere centered on the camera.
    private var timer: Timer? = nil

    /// Interval in seconds for synchronizing the position of this entity with the camera position
    private let timerInterval: TimeInterval = 0.5

    required init() {
        super.init()

        // head placed at the origin of the coordinate system
        let headSphere = ShapeResource.generateSphere(radius: headRadius)
        
        // a stick below the camera to avoid placing globes inside the user's body
        var bodyBox = ShapeResource.generateBox(width: stickWidth, height: bodyHeight, depth: stickWidth)
        bodyBox = bodyBox.offsetBy(translation: SIMD3<Float>(0, -bodyHeight / 2 - headRadius, 0))
        
        components.set(CollisionComponent(shapes: [
            headSphere,
            bodyBox
        ], mode: .trigger))
        components.set(PhysicsBodyComponent(massProperties: .default, material: .default, mode: .static))
        name = "Head + Body"
        
      
        
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { timer in
            self.update()
        }
    }
    
 
        
  
    deinit {
        timer?.invalidate()
    }
    
    func update() {
        guard let position = CameraTracker.shared.position else { return }
        let transform = Transform(
            scale: scale,
            rotation: orientation,
            translation: position
        )
        
        // This function is called whenever the camera/other globes collide with the current entity
        // I can either put a flag in sendMessage(physicsMove: true)
        // so instead of calling animateTransform I can use the move() method
        move(to: transform, relativeTo: .none, duration: timerInterval)
//        ViewModel.shared.sendMessage()
    }
}
