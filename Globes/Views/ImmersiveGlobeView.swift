//
//  ImmersiveGlobeView.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/3/2024.
//

import os
import RealityKit
import SwiftUI

/// Immersive view for rendering full-size globes and a panorama.
struct ImmersiveGlobeView: View {
    @Environment(ViewModel.self) private var model
    
    /// True if the globe entities displayed by this view need to be updated.
    @State private var globeEntitiesNeedUpdate = true
    
    /// True if the `configuration.panoramaEntity` changed and the entity displayed by this view needs to be replaced.
    @State private var panoramaEntityNeedsUpdate = true
    
    /// Image based light entity with virtual lamps
    @State private var lampsIBL: ImageBasedLightSourceEntity? = nil
    
    /// Image based light entity with even lighting
    @State private var evenIBL: ImageBasedLightSourceEntity? = nil
    
    /// Sphere centered on the camera participating in physics simulation to avoid camera position inside a globe.
    @State private var headEntity: HeadEntity? = nil
    
    /// Entity to play spatially positioned audio when two globes collide
    @State private var collisionAudioEntity: Entity? = nil
    
    /// Timer for animating globe textures
    @State var animationTimer: Timer? = nil
    
    /// If true, globe textures have a random order.
    @AppStorage("AnimationRandomOrder") private var animationRandomOrder = false
    
    /// Interval between changes of the texture for animated globes, in seconds.
    @AppStorage("AnimationInterval") private var animationInterval: Double = 5
    
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
            if let lampsIBL = await loadImageBasedLightSourceEntity(lighting: .lamps) {
                content.add(lampsIBL)
                self.lampsIBL = lampsIBL
            }
            if let evenIBL = await loadImageBasedLightSourceEntity(lighting: .even) {
                content.add(evenIBL)
                self.evenIBL = evenIBL
            }
            
            // entity to play spatially positioned audio when two globes collide
            let collisionAudioEntity = Entity()
            collisionAudioEntity.name = "Collision Audio"
            content.add(collisionAudioEntity)
            self.collisionAudioEntity = collisionAudioEntity
            
            _ = content.subscribe(to: SceneEvents.DidAddEntity.self, handleDidAddEntity(_:))
            _ = content.subscribe(to: CollisionEvents.Began.self, handleCollisionBegan(_:))
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
                ForEach(Array(model.configurations.values)) { configuration in
                    Attachment(id: configuration.globeId) {
                        OnboardingAttachmentView()
                    }
                }
            } else {
                ForEach(Array(model.configurations.values)) { configuration in
                    Attachment(id: configuration.globeId) {
                        GlobeAttachmentView(globe: configuration.globe, globeId: configuration.globeId)
                    }
                }
            }
        }
        .onChange(of: model.lighting) {
            Task { @MainActor in
                for globeEntity in model.globeEntities.values {
                    applyImageBasedLighting(to: globeEntity)
                }
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
                panoramaEntityNeedsUpdate = true
            }
        }
        .globeGestures(model: model)
        .panoramaGestures(model: model)
        .task(id: animationInterval) {
            animationTimer?.invalidate()
            animationTimer = Timer.scheduledTimer(withTimeInterval: animationInterval, repeats: true) { _ in
                Task { @MainActor in
                    animateTextures()
                }
            }
        }
    }

    @MainActor
    /// Subscribe to entity-add events to setup entities.
    ///
    /// Starting the animation and setting up IBL are only possible after the immersive space has been created and all required entities have been added.
    /// - Parameter event: The event.
    private func handleDidAddEntity(_ event: SceneEvents.DidAddEntity) {
        if let globeEntity = event.entity as? GlobeEntity {
            animateMoveIn(of: globeEntity)
            applyImageBasedLighting(to: globeEntity)
        }
    }
    
    private func handleCollisionBegan(_ collision: CollisionEvents.Began) {
        if let collisionAudioEntity {
            model.playAudio(for: collision, collisionAudioEntity: collisionAudioEntity)
        }
    }
    
    private func updateGlobeRotations() {
        Task { @MainActor in
            for (id, globeEntity) in model.globeEntities {
                if let configuration = model.configurations[id] {
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
               let attachmentEntity = attachments.entity(for: globeConfiguration.globeId) {
                attachmentEntity.position = [0, 0, globeConfiguration.globe.radius + 0.01]
                attachmentEntity.components.set(GlobeBillboardComponent(radius: globeConfiguration.globe.radius))
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
        guard let root = content.entities.first?.findEntity(named: "Globes") else { return }
        
        func noConfigurationForGlobeEntity(_ entity: Entity) -> Bool {
            guard let globeEntity = entity as? GlobeEntity else { return false }
            return !model.hasConfiguration(for: globeEntity.globeId)
        }
        
        func globeIsAdded(_ id: Globe.ID) -> Bool {
            root.children.contains(where: { ($0 as? GlobeEntity)?.globeId == id })
        }
        
        // remove globe entities for which no configuration exists
        root.children.removeAll(where: { noConfigurationForGlobeEntity($0) })
        
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
            
            // Setup image based lighting; always use even lighting for panoramas.
            // Search for the IBL in the reality view content instead of using @State evenIBL, which is nil
            // when this panorama is the first model entity added to the reality view and the immersive mode
            // is `full`, i.e. 360 degrees. This seems to be a bug in visionOS 1.2.
            let evenIBL = find(imageBasedLighting: .even, in: content)
            if let evenIBL {
                let lightReceiver = ImageBasedLightReceiverComponent(imageBasedLight: evenIBL)
                panoramaEntity.components.set(lightReceiver)
            } else {
                Logger().error("No image based lighting texture for panorama.")
            }
            
            content.add(panoramaEntity)
        }
    }
    
    // MARK: - Animate Globe Textures
    
    @MainActor
    /// Returns the next globe to load and display by an animated globe.
    /// - Parameters:
    ///   - currentGlobeId: The currently displayed globe.
    ///   - selection: The globes to select the next globe from.
    /// - Returns: The next globe, or nil if there is no next globe.
    private func nextAnimatedGlobe(currentGlobeId: Globe.ID, selection: GlobeSelection) -> Globe? {
        if animationRandomOrder {
            return model.filteredGlobes(selection: selection).randomElement()
        } else {
            let globes = model.filteredGlobes(selection: selection)
            let currentIndex = globes.firstIndex(where: { $0.id == currentGlobeId }) ?? -1
            var nextIndex = currentIndex + 1
            nextIndex = globes.indices.contains(nextIndex) ? nextIndex : 0
            if globes.isEmpty {
                return nil
            } else {
                return globes[nextIndex]
            }
        }
    }
    
    @MainActor
    /// Change the texture of all animated globes.
    private func animateTextures() {
        for globeEntity in model.globeEntities.values {
            if let configuration = model.configurations[globeEntity.globeId],
               configuration.selection != GlobeSelection.none,
               !configuration.isAnimationPaused {
                // find the next globe to show
                guard let nextGlobe = nextAnimatedGlobe(
                    currentGlobeId: configuration.globe.id,
                    selection: configuration.selection
                ) else { return }
                // Load the entire globe. Once loaded, the texture and mesh will be replaced.
                Task {
                    await SerialGlobeLoader.shared.load(globe: nextGlobe, for: globeEntity.id)
                }
            }
        }
        
        // rotation speed varies with radius and scale
        updateGlobeRotations()
        globeEntitiesNeedUpdate = true
    }
    
    // MARK: - Image Based Lighting
    
    @MainActor
    /// Load and return an image based lighting texture.
    /// - Parameter lighting: The type of IBL to load.
    /// - Returns: A new IBL entity.
    private func loadImageBasedLightSourceEntity(lighting: Lighting) async -> ImageBasedLightSourceEntity? {
        let iblEntity = await ImageBasedLightSourceEntity(
            texture: lighting.imageBasedLightingTexture,
            intensity: model.imageBasedLightIntensity)
        iblEntity?.name = lighting.description
        return iblEntity
    }
    
    /// Returns an IBL entity in the reality view content. This needs to be used when a new reality view is opened and a panorama is immediately added.
    /// In this case, the @State evenIBL has not been stored yet in SwiftUI and will be nil.
    /// - Parameters:
    ///   - imageBasedLighting: Type of IBL.
    ///   - content: Reality view content
    /// - Returns: IBL entity.
    private func find(imageBasedLighting: Lighting, in content: RealityViewContent) -> ImageBasedLightSourceEntity? {
        let entity = content.entities.first(where: { $0.name == imageBasedLighting.description })
        return entity as? ImageBasedLightSourceEntity
    }
    
    @MainActor
    /// Add an IBL receiver component to a globe entity.
    /// - Parameter globeEntity: The entity
    private func applyImageBasedLighting(to globeEntity: GlobeEntity) {
        if let iblEntity {
            let lightReceiver = ImageBasedLightReceiverComponent(imageBasedLight: iblEntity)
            globeEntity.components.set(lightReceiver)
        } else {
            globeEntity.components.remove(ImageBasedLightReceiverComponent.self)
        }
    }
    
    @MainActor
    /// The IBL entity to use. Natural lighting is not available when a panorama is visible.
    private var iblEntity: ImageBasedLightSourceEntity? {
        switch model.lighting {
        case .even:
            evenIBL
        case .lamps:
            lampsIBL
        case .natural:
            model.isShowingPanorama ? evenIBL : nil
        }
    }
}
