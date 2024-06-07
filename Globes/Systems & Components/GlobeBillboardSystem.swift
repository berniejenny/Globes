/*
 See the LICENSE.txt file for this sample’s licensing information.
 
 Abstract:
 A RealityKit system that keeps entities with a BillboardComponent facing toward the camera.
 */

import ARKit
import RealityKit
import SwiftUI

public struct GlobeBillboardComponent: Component, Codable {
    let radius: Float
}

public struct GlobeBillboardSystem: System {
    
    static let query = EntityQuery(where: .has(GlobeBillboardComponent.self))
    
    public init(scene: RealityKit.Scene) { }
    
    public func update(context: SceneUpdateContext) {
        let entities = context.scene.performQuery(Self.query).map({ $0 })
        
        guard !entities.isEmpty,
              let cameraPosition = CameraTracker.shared.position else { return }
        
        for attachmentEntity in entities {
            guard let globeEntity = attachmentEntity.parent as? GlobeEntity,
                  let radius = attachmentEntity.components[GlobeBillboardComponent.self]?.radius else { continue }
            
            // center of globe
            let globePosition = globeEntity.position(relativeTo: nil)
            
            // unary vector in global space starting at globe center and pointing towards the camera
            let n = normalize(cameraPosition - globePosition)
            
            // location on the globe that is closest to the camera with a little offset toward the camera
            let pos = globePosition + n * (radius * globeEntity.meanScale + 0.005)
            
            attachmentEntity.look(at: cameraPosition,
                        from: globePosition,
                        relativeTo: nil,
                        forward: .positiveZ)
            attachmentEntity.setPosition(pos, relativeTo: nil)
            attachmentEntity.setScale(.one, relativeTo: nil)
        }
    }
}

#Preview {
    RealityView { content, attachments in
        GlobeBillboardSystem.registerSystem()
        GlobeBillboardComponent.registerComponent()
        
        if let entity = attachments.entity(for: "previewTag") {
            
            let billboardComponent = GlobeBillboardComponent(radius: 0.3)
            entity.components[GlobeBillboardComponent.self] = billboardComponent
            
            content.add(entity)
        }
    } attachments: {
        Attachment(id: "previewTag") {
            Text("Preview")
                .font(.system(size: 100))
                .background(.pink)
        }
    }
    .previewLayout(.sizeThatFits)
}
