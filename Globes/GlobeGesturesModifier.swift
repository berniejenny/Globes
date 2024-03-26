import ARKit
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
    @Bindable var configuration: GlobeConfiguration
    
    /// The entity currently being manipulated if a gesture is in progress.
    @State private var targetedEntity: Entity?
    
    /// The scale of the globe at the start of a magnify gesture
    @State private var globeScaleAtGestureStart: Float? = nil
    
    /// The position of the globe at the start of a drag or magnify gesture
    @State private var globePositionAtGestureStart: SIMD3<Float>? = nil
    
    /// The position of the camera at the start of a magnify gesture
    @State private var cameraPositionAtGestureStart: SIMD3<Float>? = nil
    
    /// The orientation of the globe at the start of a 3D rotation gesture.
    @State private var orientationAtGestureStart: Rotation3D? = nil
    
    @State private var previousTranslationWidth: Double = 0.0
    @State private var initialIsRotationPaused: Bool? = nil
    
    enum DragState {
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
    
    @GestureState private var dragState = DragState.inactive
    
    private let minimumLongPressDuration = 0.5
    
#warning("adjust the speed of rotation to the size and distance of the globe?")
    private let rotationSpeed = 0.005
    
    func body(content: Content) -> some View {
        if configuration.enableGestures {
            content
                .gesture(doubleTapGesture)
                .simultaneousGesture(dragGesture)
                .simultaneousGesture(magnifyGesture)
                .simultaneousGesture(rotateGesture)
                .simultaneousGesture(yAxisRotateGesture)
        } else {
            content
        }
    }
    
    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .targetedToAnyEntity()
            .onEnded { _ in
                configuration.isRotationPaused.toggle()
            }
    }
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0.0)
            .targetedToAnyEntity()
            .handActivationBehavior(.pinch)
            .onChanged { value in
                
#warning("combine the following two states?")
                guard !self.dragState.isActive else { return }
                guard globeScaleAtGestureStart == nil else { return }
                
                if let targetedEntity, let globePositionAtGestureStart {
                    let location3D = value.convert(value.location3D, from: .local, to: .scene)
                    let startLocation3D = value.convert(value.startLocation3D, from: .local, to: .scene)
                    let delta = location3D - startLocation3D
                    targetedEntity.position = globePositionAtGestureStart + SIMD3<Float>(delta)
                } else {
                    // drag gesture starts
                    targetedEntity = value.entity
                    globePositionAtGestureStart = value.entity.position
                }
            }
            .onEnded { _ in
                targetedEntity = nil
                globePositionAtGestureStart = nil
            }
    }
    
    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .targetedToEntity(configuration.globeEntity ?? Entity())
            .onChanged { value in
                guard orientationAtGestureStart == nil else { return }
                
                if let globeEntity = targetedEntity as? GlobeEntity,
                    let globeScaleAtGestureStart,
                    let globePositionAtGestureStart,
                    let cameraPositionAtGestureStart {
                    let scale = max(configuration.minScale, min(configuration.maxScale, Float(value.magnification) * globeScaleAtGestureStart))
                    globeEntity.scaleAndAdjustDistanceToCamera(
                        newScale: scale,
                        oldScale: globeScaleAtGestureStart,
                        oldPosition: globePositionAtGestureStart,
                        cameraPosition: cameraPositionAtGestureStart,
                        globeRadius: configuration.globe.radius
                    )
                } else {
                    // magnify gesture starts
                    targetedEntity = value.entity
                    globeScaleAtGestureStart = value.entity.scale.x
                    globePositionAtGestureStart = value.entity.position
                    // The camera position at the start of the scaling gesture is used to move the globe.
                    // Querying the position on each update would result in an unstable position if the camera is moved laterally.
                    cameraPositionAtGestureStart = CameraTracker.shared.position
                }
            }
            .onEnded { _ in
                targetedEntity = nil
                globeScaleAtGestureStart = nil
                globePositionAtGestureStart = nil
                cameraPositionAtGestureStart = nil
            }
    }
    
    private var rotateGesture: some Gesture {
        RotateGesture3D()
            .targetedToEntity(configuration.globeEntity ?? Entity())
            .onChanged { value in
#warning("combine the following two states?")
                guard !self.dragState.isActive else { return }
                guard globeScaleAtGestureStart == nil else { return }
                
                if let globeEntity = value.entity as? GlobeEntity,
                   let orientationAtGestureStart {
                    
                    // Flip orientation of rotation to match rotation direction of hands.
                    // Flipping code from "GestureComponent.swift" of Apple sample code project "Transforming RealityKit entities using gestures"
                    // https://developer.apple.com/documentation/realitykit/transforming-realitykit-entities-with-gestures?changes=_8
                    let rotation = value.rotation
                    let flippedRotation = Rotation3D(angle: rotation.angle,
                                                     axis: RotationAxis3D(x: -rotation.axis.x,
                                                                          y: rotation.axis.y,
                                                                          z: -rotation.axis.z))
                    
                    let newOrientation = orientationAtGestureStart.rotated(by: flippedRotation)
                    globeEntity.setOrientation(.init(newOrientation), relativeTo: nil)
                } else {
                    orientationAtGestureStart = .init(value.entity.orientation(relativeTo: nil))
                }
            }
            .onEnded { _ in
                orientationAtGestureStart = nil
            }
    }
    
    private var yAxisRotateGesture: some Gesture {
        LongPressGesture(minimumDuration: minimumLongPressDuration)
            .sequenced(before: DragGesture(minimumDistance: 0.0))
            .updating($dragState) { value, state, _ in
                switch value {
                    // Long press begins.
                case .first(true):
                    state = .pressing
                    // Long press confirmed, dragging may begin.
                case .second(true, let drag):
                    DispatchQueue.main.async {
                        // remember whether rotation is enabled and pause rotation while the globe is rotated
                        if initialIsRotationPaused == nil {
                            initialIsRotationPaused = configuration.isRotationPaused
                            configuration.isRotationPaused = true
                        }
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
                    state = .inactive
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, _):
                    // Reset the previous translation width at the end of the gesture
                    previousTranslationWidth = 0.0
                    
                    // Reset the previous rotation state
                    configuration.isRotationPaused = initialIsRotationPaused ?? true
                    initialIsRotationPaused = nil
                default:
                    break
                }
            }
    }
}
