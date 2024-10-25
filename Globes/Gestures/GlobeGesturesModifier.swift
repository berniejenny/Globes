import ARKit
import os
import RealityKit
import SwiftUI

extension View {
    /// Adds gestures for moving, scaling and rotating a globe.
    @MainActor
    func globeGestures(model: ViewModel) -> some View {
        self.modifier(
            GlobeGesturesModifier(model: model)
        )
    }
}

/// A modifier that adds gestures for moving, scaling and rotating a globe.
@MainActor
private struct GlobeGesturesModifier: ViewModifier {
    
    /// State variables for drag, magnify, scale and 3D rotation gestures. State variables for the y-rotation gesture is separate.
    struct GlobeGestureState {
        var isOwner = false
        var isDragging = false
        var isScaling: Bool { scaleAtGestureStart != nil }
        var isRotating: Bool { orientationAtGestureStart != nil }
        
        /// The position of the globe at the start of a drag or magnify gesture in world coordinates
        var positionAtGestureStart: SIMD3<Float>? = nil
        
        /// The scale of the globe at the start of a magnify gesture
        var scaleAtGestureStart: Float? = nil
        
        /// The orientation of the globe at the start of a 3D rotation gesture.
        var orientationAtGestureStart: Rotation3D? = nil
        
        /// The orientation of the globe at the start of a drag gesture in the local coordinate system of the entity;
        /// used to orient the globe such that the same location is facing the camera while the globe is moved.
        var localRotationAtGestureStart: simd_quatf? = nil
        
        /// The position of the camera at the start of a magnify gesture
        var cameraPositionAtGestureStart: SIMD3<Float>? = nil
        
        /// Automatic rotation is paused during a gesture. `isRotationPausedAtStartOfGesture` remembers whether the rotation was paused before the gesture started.
        var isRotationPausedAtGestureStart: Bool? = nil
        
        /// Location of drag gesture for rotating the globe around its rotation axis
        var previousLocation3D: Point3D? = nil
        
        /// Reset all temporary properties.
        mutating func endGesture() {
            isDragging = false
            positionAtGestureStart = nil
            scaleAtGestureStart = nil
            orientationAtGestureStart = nil
            localRotationAtGestureStart = nil
            cameraPositionAtGestureStart = nil
            isRotationPausedAtGestureStart = nil
            previousLocation3D = nil
            isOwner = false
        }
    }
    
    let model: ViewModel
    
    @State private var state = GlobeGestureState()
    
    enum YRotationState {
        case inactive
        case pressing
        case dragging(translation: CGSize)
        
        var isActive: Bool {
            switch self {
            case .inactive:
                return false
            case .pressing, .dragging:
                return true
            }
        }
    }
    
    @GestureState private var yRotationState = YRotationState.inactive
    
    private let minimumLongPressDuration = 0.5
    
    /// Amount of angular rotation per translation delta for single-handed rotation around the y-axis. This value is reduced for enlarged globes.
    private let rotationSpeed: Float = 0.0015
    
    // duration of an animate run each time the transformation changes, as in the Apple EntityGestures sample project
    private let animationDuration = 0.2
    
    /// If the globes is farther away than this distance and it is tapped to show an attachment view.
    private let maxDistanceToCameraWhenTapped: Float = 1.5
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(doubleTapGesture)
            .simultaneousGesture(singleTapGesture)
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(magnifyGesture)
            .simultaneousGesture(rotateGesture)
            .simultaneousGesture(rotateGlobeAxisGesture)
    }
    
    private var singleTapGesture: some Gesture {
        TapGesture(count: 1)
            .targetedToAnyEntity()
            .onEnded { value in
                if let globeEntity = value.entity as? GlobeEntity,
                   var configuration = model.configurations[globeEntity.globeId] {
                    configuration.showAttachment.toggle()
                    model.configurations[globeEntity.globeId] = configuration
                    model.showOnboarding = false
                    // if the attachment view is newly shown and the globe is too far from the camera, move it closer to the camera.
                    if configuration.showAttachment {
                        let scaledRadius = configuration.globe.radius * globeEntity.meanScale
                        if let distance = try? globeEntity.distanceToCamera(radius: scaledRadius),
                           distance > maxDistanceToCameraWhenTapped {
                            globeEntity.moveTowardCamera(distance: maxDistanceToCameraWhenTapped, radius: scaledRadius, duration: 1)
                        }
                    }
                    
                    model.activityState.globeTransformations[globeEntity.globeId]?.globeChange = GlobeChange.transform
                    // Only claim ownership if this device is not already the owner
                    model.forceClaimOwnership()
                }
            }
    }
    
    /// Double pinch gesture for starting and stoping globe rotation.
    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .targetedToAnyEntity()
            .onEnded { value in
                if let globeId = (value.entity as? GlobeEntity)?.globeId,
                   var configuration = model.configurations[globeId] {
                    configuration.isRotationPaused.toggle()
                    model.configurations[globeId] = configuration
                }
                model.forceClaimOwnership()
            }
    }
    
    /// Drag gesture to reposition the globe.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0.0)
            .targetedToAnyEntity()
            .handActivationBehavior(.automatic) // allow for globe to be pushed when the hand or a finger intersects it
            .onChanged { value in
                model.forceClaimOwnership()
                Task { @MainActor in
                    guard !state.isScaling,
                          !state.isRotating,
                          !yRotationState.isActive else {
                        log("exit drag")
                        return
                    }
                    if state.positionAtGestureStart == nil {
                        log("start drag")
                        state.isDragging = true
                        state.positionAtGestureStart = value.entity.position(relativeTo: nil)
                        state.localRotationAtGestureStart = (value.entity as? GlobeEntity)?.orientation
                    }
                    
                    if let positionAtGestureStart = state.positionAtGestureStart,
                       let localRotationAtGestureStart = state.localRotationAtGestureStart,
                       let globeEntity = value.entity as? GlobeEntity,
                       let cameraPosition = CameraTracker.shared.position {
                        log("update drag")
                        let location3D = value.convert(value.location3D, from: .local, to: .scene)
                        let startLocation3D = value.convert(value.startLocation3D, from: .local, to: .scene)
                        let delta = location3D - startLocation3D
                        let position = positionAtGestureStart + SIMD3<Float>(delta)
                        
                        // rotate the globe around a vertical axis (which is different to the globe's axis if it is not north-oriented)
                        // such that the same location is facing the camera as the globe is dragged horizontally around the camera
                        var v1 = cameraPosition - positionAtGestureStart
                        var v2 = cameraPosition - position
                        v1.y = 0
                        v2.y = 0
                        v1 = normalize(v1)
                        v2 = normalize(v2)
                        let rotationSinceStart = simd_quatf(from: v1, to: v2)
                        let localRotationSinceStart = simd_quatf(value.convert(rotation: rotationSinceStart, from: .scene, to: .local))
                        let rotation = simd_mul(localRotationSinceStart, localRotationAtGestureStart)
                        
                        
                        // animate the transformation to reduce jitter, as in the Apple EntityGestures sample project
                        globeEntity.animateTransform(orientation: rotation, position: position, duration: animationDuration)
                    }
                }
            }
            .onEnded { value in
                log("end drag")
                state.endGesture()
                
                // Once the drag gesture is over we want to send the changes. This is because it would be unecessary to send messages while we are dragging.
                if let globeEntity = value.entity as? GlobeEntity {
                    // Capture the latest transformation
                    let finalPosition = globeEntity.position(relativeTo: nil)
                    let finalOrientation = globeEntity.orientation
                    
                    #warning("sometimes when other users load the globe, the local users activity changes and sharedglobeconfiguration is not initialized. Hence, the globes become unsynced")
                    // Update the activity state immediately
//                    model.activityState.globeTransformations[globeEntity.globeId]?.position = finalPosition
//                    model.activityState.globeTransformations[globeEntity.globeId]?.orientation = finalOrientation
//                    model.activityState.globeTransformations[globeEntity.globeId]?.globeChange = GlobeChange.transform
//                    
//                    // Send the updated transformation
//                    model.sendMessage()
                    
                    model.updateShareGlobe(globeID: globeEntity.globeId,
                                               scale: globeEntity.scale.x,
                                               orientation: finalOrientation,
                                               position: finalPosition,
                                               model: model,
                                               globeChange: GlobeChange.transform)
                }
            }
    }
    
    private var magnifyGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0)
            .targetedToAnyEntity()
            .onChanged { value in
                Task { @MainActor in
                    guard let globeEntity = value.entity as? GlobeEntity else { return }
                    guard !state.isRotating, !yRotationState.isActive else {
                        log("exit magnify")
                        return
                    }
                    if !state.isScaling {
                        log("start magnify")
                        state.scaleAtGestureStart = globeEntity.meanScale
                        state.positionAtGestureStart = value.entity.position
                        // The camera position at the start of the scaling gesture is used to move the globe.
                        // Querying the position on each update would result in an unstable globe position if the camera is moved.
                        state.cameraPositionAtGestureStart = CameraTracker.shared.position
                    }
                    
                    if let globeScaleAtGestureStart = state.scaleAtGestureStart,
                       let globePositionAtGestureStart = state.positionAtGestureStart,
                       let cameraPositionAtGestureStart = state.cameraPositionAtGestureStart {
                        log("update magnify")
                        if let globeId = (value.entity as? GlobeEntity)?.globeId,
                           let configuration = model.configurations[globeId] {
                            let scale = max(configuration.minScale, min(configuration.maxScale, Float(value.magnification) * globeScaleAtGestureStart))
                            globeEntity.scaleAndAdjustDistanceToCamera(
                                newScale: scale,
                                oldScale: globeScaleAtGestureStart,
                                oldPosition: globePositionAtGestureStart,
                                cameraPosition: cameraPositionAtGestureStart, 
                                radius: configuration.globe.radius,
                                duration: animationDuration // animate the transformation to reduce jitter, as in the Apple EntityGestures sample project
                            )
                        }
                    }
                    model.forceClaimOwnership()
                }
            }
            .onEnded { value in
                state.endGesture()
                log("end magnify")
                
                if let globeEntity = value.entity as? GlobeEntity {
                    model.updateShareGlobe(globeID: globeEntity.globeId,
                                               scale: globeEntity.scale.x,
                                               model: model,
                                               globeChange: GlobeChange.transform)
                }
            }
    }
    
    /// Two-handed rotation gesture for 3D rotation.
    private var rotateGesture: some Gesture {
        RotateGesture3D()
            .targetedToAnyEntity()
            .onChanged { value in
                Task { @MainActor in
                    guard !state.isScaling, !yRotationState.isActive else {
                        log ("exit rotate")
                        return
                    }
                    if !state.isRotating {
                        log("start rotate")
                        state.orientationAtGestureStart = .init(value.entity.orientation(relativeTo: nil))
                        
                        if let globeId = (value.entity as? GlobeEntity)?.globeId {
                            Task { @MainActor in
                                pauseRotationAndStoreRotationState(globeId)
                            }
                        }
                    }
                    
                    if let globeEntity = value.entity as? GlobeEntity,
                       let orientationAtGestureStart = state.orientationAtGestureStart {
                        log("update rotate")
                        
                        // reduce the rotation angle for enlarged globes to avoid excessively fast movements
                        let rotation = value.rotation
                        let scale = max(1, Double(globeEntity.meanScale))
                        let angle = Angle2D(radians: rotation.angle.radians / scale)
                        
                        // Flip orientation of rotation to match rotation direction of hands.
                        // Flipping code from "GestureComponent.swift" of Apple sample code project "Transforming RealityKit entities using gestures"
                        // https://developer.apple.com/documentation/realitykit/transforming-realitykit-entities-with-gestures?changes=_8
                        let flippedRotation = Rotation3D(angle: angle,
                                                         axis: RotationAxis3D(x: -rotation.axis.x,
                                                                              y: rotation.axis.y,
                                                                              z: -rotation.axis.z))
                        
                        let newOrientation = orientationAtGestureStart.rotated(by: flippedRotation)
                        globeEntity.animationPlaybackController?.stop()
                        globeEntity.orientation = simd_quatf(newOrientation)
                    }
                    model.forceClaimOwnership()
                }
            }
            .onEnded { value in
                log("end rotate")
                
                // Reset the previous rotation state
                if let paused = state.isRotationPausedAtGestureStart,
                   let globeId = (value.entity as? GlobeEntity)?.globeId,
                   var configuration = model.configurations[globeId] {
                    configuration.isRotationPaused = paused
                    model.configurations[globeId] = configuration	
                
                }
                
                state.endGesture()
                
                if let globeEntity = value.entity as? GlobeEntity {
                    model.activityState.globeTransformations[globeEntity.globeId]?.globeChange = GlobeChange.transform
                }
            }
    }
    
    /// One-handed gesture to rotate globe around the vertical y-axis.
    private var rotateGlobeAxisGesture: some Gesture {
        LongPressGesture(minimumDuration: minimumLongPressDuration)
            .sequenced(before: DragGesture(minimumDistance: 0.0))
            .targetedToAnyEntity()
            .updating($yRotationState) { value, yRotationState, _ in
                guard let entity = value.entity as? GlobeEntity else { return }
                switch value.gestureValue {
                    // Long press begins.
                case .first(true):
                    yRotationState = .pressing
                    // Long press confirmed, dragging may begin.
                case .second(true, let drag):
                    if let globeId = (value.entity as? GlobeEntity)?.globeId {
                        Task { @MainActor in
                            pauseRotationAndStoreRotationState(globeId)
                        }
                    }
                    
                    guard let drag = drag else { return }
                    
                    Task { @MainActor in
                        if let globeId = (value.entity as? GlobeEntity)?.globeId,
                           let configuration = model.configurations[globeId] {
                            
                            if state.previousLocation3D == nil {
                                state.previousLocation3D = drag.location3D
                            }
                            guard let previousLocation3D = state.previousLocation3D else { return }
                            
                            // Map the horizontal displacement of the hand to a rotation around the rotation axis of the globe.
                            // Place a temporary entity at the center of the globe and orient its z-axis toward the camera and the
                            // x-axis in horizontal direction. Then transform the hand gesture movement to the coordinate system
                            // of the temporary entity and compute the horizontal delta since the last update.
                            guard let cameraPosition = CameraTracker.shared.position else { return }
                            var v2 = cameraPosition - entity.position
                            v2.y = 0 // work in x-z plane
                            v2 = normalize(v2)
                            let rotation = simd_quatf(from: [0, 0, 1], to: v2) // have z-axis point at the camera
                            let rotatedEntity = Entity()
                            rotatedEntity.position = entity.position
                            rotatedEntity.orientation = rotation

                            // Transform hand gesture coordinates from the globe entity to the temporary entity.
                            var location = value.convert(drag.location3D, from: .local, to: rotatedEntity)
                            var previousLocation = value.convert(previousLocation3D, from: .local, to: rotatedEntity)
                            location.y = 0
                            previousLocation.y = 0
                            let deltaTranslation = location.x - previousLocation.x
                            state.previousLocation3D = drag.location3D
                            
                            // Adjust the amount of rotation per translation delta to the size of the globe.
                            // The angular rotation per translation delta is reduced for enlarged globes.
                            let scaleRadius = max(1, entity.meanScale) * configuration.globe.radius
                            let rotationAmount = Float(deltaTranslation) * rotationSpeed / scaleRadius * 1000
                            
                            // A rotation quaternion around the globe's rotation axis.
                            entity.animationPlaybackController?.stop()
                            entity.orientation *= simd_quatf(angle: rotationAmount, axis: SIMD3<Float>(0, 1, 0))
                        }
                    }
                    model.forceClaimOwnership()
                    // Dragging ended or the long press cancelled.
                default:
                    yRotationState = .inactive
                }
            }
            .onEnded { value in
                switch value.gestureValue {
                case .second(true, _):
                    // Reset the previous rotation state
                    if let paused = state.isRotationPausedAtGestureStart,
                       let globeId = (value.entity as? GlobeEntity)?.globeId,
                       var configuration = model.configurations[globeId] {
                        configuration.isRotationPaused = paused
                        model.configurations[globeId] = configuration
                    }
                    
                    state.endGesture()
                    
                    if let globeEntity = value.entity as? GlobeEntity {
                        model.activityState.globeTransformations[globeEntity.globeId]?.globeChange = GlobeChange.transform
                    }
                default:
                    break
                }
            }
    }
    
    /// Pauses automatic rotation of the globe while the globe is rotated by a gesture, and stores the automatic rotation state.
    private func pauseRotationAndStoreRotationState(_ globeId: Globe.ID) {
        if state.isRotationPausedAtGestureStart == nil,
           var configuration = model.configurations[globeId] {
            state.isRotationPausedAtGestureStart = configuration.isRotationPaused
            configuration.isRotationPaused = true
            model.configurations[globeId] = configuration
        }
    }
    
    private func log(_ message: String) {
#if DEBUG
//        let logger = Logger(subsystem: "Globe Gestures", category: "Gestures")
//        logger.info("\(message)")
#endif
    }
}
