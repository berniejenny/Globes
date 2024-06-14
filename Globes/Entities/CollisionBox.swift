//
//  CollisionBox.swift
//  Globes
//
//  Created by Bernhard Jenny on 27/5/2024.
//

import RealityKit

/// Box for inside-out collision detection with added CollisionFilters such that the box does not participate in physics simulations.
/// https://developer.apple.com/forums/thread/743623?answerId=776215022#776215022
/// https://developer.apple.com/documentation/realitykit/inputtargetcomponent
class CollisionBox: Entity {
    
    let size: Float
    
    @MainActor
    required init() {
        self.size = 1
        super.init()
    }
    
    @MainActor
    init(size: Float) {
        self.size = size
        super.init()
        
        let smallDimension: Float = 0.001
        let offset = size / 2
        
        // right face
        let right = Entity()
        right.name = "right"
        right.components.set(CollisionComponent(shapes: [.generateBox(width: smallDimension, height: size, depth: size)], filter: CollisionFilter(group: [], mask: [])))
        right.position.x = offset
        
        // left face
        let left = Entity()
        left.name = "left"
        left.components.set(CollisionComponent(shapes: [.generateBox(width: smallDimension, height: size, depth: size)], filter: CollisionFilter(group: [], mask: [])))
        left.position.x = -offset
        
        // top face
        let top = Entity()
        top.name = "top"
        top.components.set(CollisionComponent(shapes: [.generateBox(width: size, height: smallDimension, depth: size)], filter: CollisionFilter(group: [], mask: [])))
        top.position.y = offset
        
        // bottom face
        let bottom = Entity()
        bottom.name = "bottom"
        bottom.components.set(CollisionComponent(shapes: [.generateBox(width: size, height: smallDimension, depth: size)], filter: CollisionFilter(group: [], mask: [])))
        bottom.position.y = -offset
        
        // front face
        let front = Entity()
        front.name = "front"
        front.components.set(CollisionComponent(shapes: [.generateBox(width: size, height: size, depth: smallDimension)], filter: CollisionFilter(group: [], mask: [])))
        front.position.z = offset
        
        // back face
        let back = Entity()
        back.name = "back"
        back.components.set(CollisionComponent(shapes: [.generateBox(width: size, height: size, depth: smallDimension)], filter: CollisionFilter(group: [], mask: [])))
        back.position.z = -offset
        
        // All faces.
        let faces = [right, left, top, bottom, front, back]
        
        for face in faces {
            face.components.set(InputTargetComponent())
        }
        
        self.children.append(contentsOf: faces)
    }
}
