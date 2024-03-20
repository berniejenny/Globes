/*
 Modified version of PlacementGesturesModifier of the Apple `Hello World` project
 https://developer.apple.com/documentation/visionos/world
 */

import SwiftUI
import RealityKit

extension View {
    /// Listens for gestures and places an item based on those inputs.
    func globeGestures(
        configuration: GlobeEntity.Configuration,
        initialPosition: Point3D = .zero,
        axZoomIn: Bool = false,
        axZoomOut: Bool = false
    ) -> some View {
        self.modifier(
            GlobeGesturesModifier(
                configuration: configuration,
                initialPosition: initialPosition,
                axZoomIn: axZoomIn,
                axZoomOut: axZoomOut
            )
        )
    }
}

/// A modifier that adds gestures and positioning to a view.
private struct GlobeGesturesModifier: ViewModifier {
    @Bindable var configuration: GlobeEntity.Configuration
    var initialPosition: Point3D
    var axZoomIn: Bool
    var axZoomOut: Bool
    
    @State private var scale: Double = 1
    @State private var startScale: Double? = nil
    @State private var position: Point3D = .zero
    @State private var startPosition: Point3D? = nil
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
    
    private let minimumLongPressDuration = 0.5
    private let rotationSpeed = 0.005
    
    @GestureState private var dragState = DragState.inactive
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                position = initialPosition
            }
            .position(x: position.x, y: position.y)
            .offset(z: position.z)
        
        // Enable people to move the model anywhere in their space.
            .simultaneousGesture(DragGesture(minimumDistance: 0.0, coordinateSpace: .global)
                .handActivationBehavior(.pinch)
                .onChanged { value in
                    guard !self.dragState.isActive else { return }
                    if let startPosition {
                        let delta = value.location3D - value.startLocation3D
                        position = startPosition + delta
                    } else {
                        startPosition = position
                    }
                }
                .onEnded { _ in
                    startPosition = nil
                }
            )
        
        // Enable people to scale the model within certain bounds.
            .simultaneousGesture(MagnifyGesture()
                .onChanged { value in
                    if let startScale {
                        scale = max(configuration.minScale, min(configuration.maxScale, value.magnification * startScale))
                        configuration.globeEntity?.globeScale = Float(scale)
                    } else {
                        if let globeEntity = configuration.globeEntity {
                            startScale = Double(globeEntity.globeScale)
                        }
                    }
                }
                .onEnded { _ in
                    startScale = nil
                }
            )
        // Enable people to rotate the globe (after a pinch and hold)
            .simultaneousGesture(
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
            )
            .onChange(of: axZoomIn) {
                scale = max(0.1, min(3, scale + 0.2))
                startScale = scale
            }
            .onChange(of: axZoomOut) {
                scale = max(0.1, min(3, scale - 0.2))
                startScale = scale
            }
    }
}
