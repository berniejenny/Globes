//
//  ImmersiveGlobeView.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/3/2024.
//

import RealityKit
import SwiftUI

/// Immersive view for rendering full-size globes and a panorama.
struct ImmersiveGlobeView: View {
    @Environment(ViewModel.self) private var model
    
    /// True if the globe entities displayed by this view need to be updated.
    @State private var globeEntitiesNeedUpdate = true
    
    /// True if the `configuration.panoramaEntity` changed and the entity displayed by this view needs to be replaced.
    @State private var panoramaEntityNeedsUpdate = true
    
    /// IBL entity if virtual light is used.
    @State private var lampsIBL: ImageBasedLightSourceEntity? = nil
    @State private var evenIBL: ImageBasedLightSourceEntity? = nil
    
    /// Sphere centered on the camera participating in physics simulation to avoid camera position inside a globe.
    @State private var headEntity: HeadEntity? = nil
    
    var body: some View {
        RealityView { content, attachments in
            let root = Entity()
            root.name = "Globes"
            content.add(root)
            
            // sphere at camera position
            let headEntity = HeadEntity()
            root.addChild(headEntity)
            Task { @MainActor in
                self.headEntity = headEntity
            }
            
            // zero gravity physics simulation
            var physicsSimulationComponent = PhysicsSimulationComponent()
            physicsSimulationComponent.gravity = SIMD3.zero
            root.components.set(physicsSimulationComponent)
            
            // image based lighting images shared by all globes and the panorama
            lampsIBL = await loadImageBaseLightSourceEntity(lighting: .lamps)
            evenIBL = await loadImageBaseLightSourceEntity(lighting: .even)
            if let lampsIBL { content.add(lampsIBL) }
            if let evenIBL { content.add(evenIBL) }
            
            // Subscribe to add events to trigger move-in animation.
            // The animation can only start after the immersive space has been created and the entity added.
            let _ = content.subscribe(to: SceneEvents.DidAddEntity.self) { event in
                animateMoveIn(of: event.entity)
            }
        } update: { content, attachments in
            if globeEntitiesNeedUpdate {
                addGlobeEntities(to: content, attachments: attachments)
                Task { @MainActor in
                    globeEntitiesNeedUpdate = false
                }
            }
            
            if panoramaEntityNeedsUpdate {
                addPanoramaEntity(to: content)
                Task { @MainActor in
                    panoramaEntityNeedsUpdate = false
                }
            }
        } attachments: {
            if model.showOnboarding {
                ForEach(model.globes) { globe in
                    Attachment(id: globe.id) {
                       OnboardingAttachmentView()
                    }
                }
            } else {
                ForEach(model.globes) { globe in
                    Attachment(id: globe.id) {
                        GlobeAttachmentView(globe: globe)
                    }
                }
            }
        }
        .onChange(of: model.lighting) {
            Task { @MainActor in
                applyImageBasedLighting()
            }
        }
        .onChange(of: model.configurations) {
            Task { @MainActor in
                updateGlobeRotations()
                globeEntitiesNeedUpdate = true
            }
        }
        .onChange(of: model.globeEntities.keys) {
            Task { @MainActor in
                applyImageBasedLighting() // only apply IBL once entities exist, not when model.showPanorama changes
                globeEntitiesNeedUpdate = true
            }
        }
        .onChange(of: model.rotateGlobes) {
            Task { @MainActor in
                globeEntitiesNeedUpdate = true
            }
        }
        .onChange(of: model.panoramaEntity) {
            Task { @MainActor in
                applyImageBasedLighting() // only apply IBL once the panorama entity exists, not when model.showPanorama changes
                panoramaEntityNeedsUpdate = true
            }
        }
        .globeGestures(model: model)
        .panoramaGestures(model: model)
    }
    
    private func updateGlobeRotations() {
        Task { @MainActor in
            for id in model.globeEntities.keys {
                if let configuration = model.configurations[id],
                   let globeEntity = model.globeEntities[id] {
                    globeEntity.updateRotation(configuration: configuration)
                }
            }
        }
    }
    
    @MainActor
    private func addAttachments(_ attachments: RealityViewAttachments) {
        for globeEntity in model.globeEntities.values {
            if let globeConfiguration = model.configurations[globeEntity.globeId],
               globeConfiguration.showAttachment || model.showOnboarding,
               let attachmentEntity = attachments.entity(for: globeEntity.globeId) {
                attachmentEntity.position = [0, 0, globeConfiguration.radius + 0.01]
                attachmentEntity.components.set(GlobeBillboardComponent(radius: globeConfiguration.radius))
                globeEntity.addChild(attachmentEntity)
            } else {
                for viewAttachmentEntity in globeEntity.children where viewAttachmentEntity is ViewAttachmentEntity {
                    globeEntity.removeChild(viewAttachmentEntity)
                }
            }
        }
    }

    @MainActor
    /// Add new globe entities, remove globe entities that no longer exist, and update globe view attachments.
    /// - Parameters:
    ///   - content: Root of scene content.
    ///   - attachments: The attachments for the globes.
    private func addGlobeEntities(to content: RealityViewContent, attachments: RealityViewAttachments) {
        guard let root = content.entities.first(where: { $0.name == "Globes" }) else { return }
        
        func globeExist(_ entity: Entity) -> Bool {
            guard let globeEntity = entity as? GlobeEntity else { return false }
            return model.hasConfiguration(for: globeEntity.globeId)
        }
        
        func globeIsAdded(_ id: Globe.ID) -> Bool {
            root.children.contains(where: { ($0 as? GlobeEntity)?.globeId == id })
        }
        
        // remove globe entities for which no configuration exists
        root.children.removeAll(where: { !globeExist($0) })
                                            
        // add new globe entities
        for entity in model.globeEntities.values where !globeIsAdded(entity.globeId) {
            root.addChild(entity)
        }
        
        // update attachments
        addAttachments(attachments)
    }
    
    @MainActor
    /// Move-in animation that changes the position and the scale of a globe.
    /// - Parameter entity: The globe entity.
    private func animateMoveIn(of entity: Entity) {
        if let globeEntity = entity as? GlobeEntity {
            let targetPosition = model.targetPosition(for: globeEntity.globeId)
            globeEntity.animateTransform(scale: 1, position: targetPosition)
        }
    }
    
    private func loadImageBaseLightSourceEntity(lighting: Lighting) async -> ImageBasedLightSourceEntity? {
        return await ImageBasedLightSourceEntity(
            texture: lighting.imageBasedLightingTexture,
            intensity: model.imageBasedLightIntensity)
    }
    
    @MainActor
    private func applyImageBasedLighting() {
        // natural lighting is not available when a panorama is visible
        let iblEntity: ImageBasedLightSourceEntity?
        switch model.lighting {
        case .even:
            iblEntity = evenIBL
        case .lamps:
            iblEntity = lampsIBL
        case .natural:
            iblEntity = model.isShowingPanorama ? evenIBL : nil
        }
        
        for globeEntity in model.globeEntities.values {
            if let iblEntity {
                let lightReceiver = ImageBasedLightReceiverComponent(imageBasedLight: iblEntity)
                globeEntity.components.set(lightReceiver)
            } else {
                globeEntity.components.remove(ImageBasedLightReceiverComponent.self)
            }
        }
      
        if let iblEntity {
            let lightReceiver = ImageBasedLightReceiverComponent(imageBasedLight: iblEntity)
            model.panoramaEntity?.components.set(lightReceiver)
        }
    }
    
    @MainActor
    private func addPanoramaEntity(to content: RealityViewContent) {
        // remove current panorama
        if let oldPanoramaEntity = content.entities.first(where: { $0 is PanoramaEntity }) {
            content.remove(oldPanoramaEntity)
            model.panoramaEntity?.orientation = oldPanoramaEntity.orientation
        }
        
        if let panoramaEntity = model.panoramaEntity {
            // move to camera center
            if let cameraPosition = CameraTracker.shared.position {
                panoramaEntity.position = cameraPosition
            }
            
            content.add(panoramaEntity)
        }
    }
}
