import ARKit
import os
import RealityKit
import SwiftUI

extension View {
    /// Adds gestures for moving, scaling and rotating a globe.
    func globeGestures(configuration: GlobeConfiguration) -> some View {
        self.modifier(
            GlobeGesturesModifier(configuration: configuration)
        )
    }
}

/// A modifier that adds gestures and positioning to a view.
private struct GlobeGesturesModifier: ViewModifier {
    
    /// State variables for drag, magnify, scale and 3D rotation gestures. State variables for the y-rotation gesture is separate.
    struct GlobeGestureState {
        var isDragging = false
        var isScaling: Bool { scaleAtGestureStart != nil }
        var isRotating: Bool { orientationAtGestureStart != nil }
        
        /// The position of the globe at the start of a drag or magnify gesture
        var positionAtGestureStart: SIMD3<Float>? = nil
        
        /// The scale of the globe at the start of a magnify gesture
        var scaleAtGestureStart: Float? = nil
        
        /// The orientation of the globe at the start of a 3D rotation gesture.
        var orientationAtGestureStart: Rotation3D? = nil
        
        /// The position of the camera at the start of a magnify gesture
        var cameraPositionAtGestureStart: SIMD3<Float>? = nil
        
        var isRotationPausedAtStartOfGesture: Bool? = nil
        
        mutating func endGesture() {
            isDragging = false
            positionAtGestureStart = nil
            scaleAtGestureStart = nil
            orientationAtGestureStart = nil
            cameraPositionAtGestureStart = nil
            isRotationPausedAtStartOfGesture = nil
        }
    }
    
    @Bindable var configuration: GlobeConfiguration
    
    @State private var previousTranslationWidth: Double = 0.0
    
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
    
#warning("adjust the speed of rotation to the size and distance of the globe")
    private let rotationSpeed = 0.005
    
    func body(content: Content) -> some View {
        if configuration.enableGestures {
            content
                .simultaneousGesture(doubleTapGesture)
                .simultaneousGesture(dragGesture)
                .simultaneousGesture(magnifyGesture)
                .simultaneousGesture(rotateGesture)
                .simultaneousGesture(yAxisRotateGesture)
        } else {
            content
        }
    }
    
    /// Double pinch gesture for starting and stoping globe rotation.
    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .targetedToEntity(configuration.globeEntity ?? Entity())
            .onEnded { _ in
                configuration.isRotationPaused.toggle()
            }
    }
    
    /// Drag gesture to reposition the globe.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0.0)
            .targetedToEntity(configuration.globeEntity ?? Entity())
            .handActivationBehavior(.automatic) // allow for globes being pushed when the hand or a finger intersects it
            .onChanged { value in
                
                guard !state.isScaling,
                      !state.isRotating,
                      !yRotationState.isActive else {
                    log("exit drag")
                    return
                }
                if state.positionAtGestureStart == nil {
                    log("start drag")
                    state.isDragging = true
                    state.positionAtGestureStart = value.entity.position
                }
                
                if let globePositionAtGestureStart = state.positionAtGestureStart {
                    log("update drag")
                    let location3D = value.convert(value.location3D, from: .local, to: .scene)
                    let startLocation3D = value.convert(value.startLocation3D, from: .local, to: .scene)
                    let delta = location3D - startLocation3D
                    value.entity.position = globePositionAtGestureStart + SIMD3<Float>(delta)
                }
            }
            .onEnded { _ in
                log("end drag")
                state.endGesture()
            }
    }
    
    private var magnifyGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0)
            .targetedToEntity(configuration.globeEntity ?? Entity())
            .onChanged { value in
                guard let globeEntity = value.entity as? GlobeEntity else { return }
                guard !state.isRotating, !yRotationState.isActive else {
                    log("exit magnify")
                    return
                }
                if !state.isScaling {
                    log("start magnify")
                    state.scaleAtGestureStart = globeEntity.uniformScale
                    state.positionAtGestureStart = value.entity.position
                    // The camera position at the start of the scaling gesture is used to move the globe.
                    // Querying the position on each update would result in an unstable globe position if the camera is moved.
                    state.cameraPositionAtGestureStart = CameraTracker.shared.position
                }
                
                if let globeScaleAtGestureStart = state.scaleAtGestureStart,
                   let globePositionAtGestureStart = state.positionAtGestureStart,
                   let cameraPositionAtGestureStart = state.cameraPositionAtGestureStart {
                    log("update magnify")
                    let scale = max(configuration.minScale, min(configuration.maxScale, Float(value.magnification) * globeScaleAtGestureStart))
                    globeEntity.scaleAndAdjustDistanceToCamera(
                        newScale: scale,
                        oldScale: globeScaleAtGestureStart,
                        oldPosition: globePositionAtGestureStart,
                        cameraPosition: cameraPositionAtGestureStart,
                        globeRadius: configuration.globe.radius
                    )
                }
            }
            .onEnded { _ in
                state.endGesture()
                log("end magnify")
            }
    }
    
    /// Two-handed rotation gesture for 3D rotation.
    private var rotateGesture: some Gesture {
        RotateGesture3D()
            .targetedToEntity(configuration.globeEntity ?? Entity())
            .onChanged { value in
                guard !state.isScaling, !yRotationState.isActive else {
                    log ("exit rotate")
                    return
                }
                if !state.isRotating {
                    log("start rotate")
                    state.orientationAtGestureStart = .init(value.entity.orientation(relativeTo: nil))
                    
                    DispatchQueue.main.async {
                        pauseRotationAndStoreRotationState()
                    }
                }
                
                if let globeEntity = value.entity as? GlobeEntity,
                   let orientationAtGestureStart = state.orientationAtGestureStart {
                    log("update rotate")
                    // Flip orientation of rotation to match rotation direction of hands.
                    // Flipping code from "GestureComponent.swift" of Apple sample code project "Transforming RealityKit entities using gestures"
                    // https://developer.apple.com/documentation/realitykit/transforming-realitykit-entities-with-gestures?changes=_8
                    let rotation = value.rotation
                    let flippedRotation = Rotation3D(angle: rotation.angle,
                                                     axis: RotationAxis3D(x: -rotation.axis.x,
                                                                          y: rotation.axis.y,
                                                                          z: -rotation.axis.z))
                    
                    let newOrientation = orientationAtGestureStart.rotated(by: flippedRotation)
                    globeEntity.globeOrientation = simd_quatf(newOrientation)
                }
            }
            .onEnded { _ in
                log("end rotate")
                // Reset the previous rotation state
                if let paused = state.isRotationPausedAtStartOfGesture {
                    configuration.isRotationPaused = paused
                }
                
                state.endGesture()
            }
    }
    
    /// One-handed gesture to rotate globe around the vertical y-axis.
    private var yAxisRotateGesture: some Gesture {
        LongPressGesture(minimumDuration: minimumLongPressDuration)
            .sequenced(before: DragGesture(minimumDistance: 0.0))
            .updating($yRotationState) { value, yRotationState, _ in
                switch value {
                    // Long press begins.
                case .first(true):
                    yRotationState = .pressing
                    // Long press confirmed, dragging may begin.
                case .second(true, let drag):
                    DispatchQueue.main.async {
                        pauseRotationAndStoreRotationState()
                    }
                    
                    guard let drag = drag else { return }
                    
                    // Update the previous translation width for the next frame
                    DispatchQueue.main.async {
                        let deltaTranslation = drag.translation.width - previousTranslationWidth
                        previousTranslationWidth = drag.translation.width
                        
                        // Multiplier can be adjusted as needed
                        let rotationAmount = Float(deltaTranslation * rotationSpeed)
                        
                        // Create a rotation quaternion around the Y axis
                        let rotation = simd_quatf(angle: rotationAmount, axis: SIMD3<Float>(0, 1, 0))
                        
                        // Apply rotation to the entity
                        configuration.globeEntity?.rotate(by: rotation)
                    }
                    
                    // Dragging ended or the long press cancelled.
                default:
                    yRotationState = .inactive
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, _):
                    // Reset the previous translation width at the end of the gesture
                    previousTranslationWidth = 0.0
                    
                    // Reset the previous rotation state
                    if let paused = state.isRotationPausedAtStartOfGesture {
                        configuration.isRotationPaused = paused
                    }
                    
                    state.endGesture()
                default:
                    break
                }
            }
    }
    
    /// Pauses automatic rotation of the globe while the globe is rotated by a gesture, and stores the automatic rotation state.
    private func pauseRotationAndStoreRotationState() {
        if state.isRotationPausedAtStartOfGesture == nil {
            state.isRotationPausedAtStartOfGesture = configuration.isRotationPaused
            configuration.isRotationPaused = true
        }
    }
    
    private func log(_ message: String) {
#if DEBUG
        let logger = Logger(subsystem: "Globe Gestures", category: "Gestures")
        logger.info("\(message)")
#endif
    }
}
