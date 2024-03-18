/*
 From the Apple Hello World project
 https://developer.apple.com/documentation/visionos/world

Abstract:
A modifier for placing objects.
*/

import SwiftUI
import RealityKit

extension View {
    /// Listens for gestures and places an item based on those inputs.
    func placementGestures(
        globeEntity: GlobeEntity?,
        initialPosition: Point3D = .zero,
        axZoomIn: Bool = false,
        axZoomOut: Bool = false
    ) -> some View {
        self.modifier(
            PlacementGesturesModifier(
                globeEntity: globeEntity,
                initialPosition: initialPosition,
                axZoomIn: axZoomIn,
                axZoomOut: axZoomOut
            )
        )
    }
}

/// A modifier that adds gestures and positioning to a view.
private struct PlacementGesturesModifier: ViewModifier {
    var globeEntity: GlobeEntity?
    var initialPosition: Point3D
    var axZoomIn: Bool
    var axZoomOut: Bool

    @State private var scale: Double = 1
    @State private var startScale: Double? = nil
    @State private var position: Point3D = .zero
    @State private var startPosition: Point3D? = nil
    @State private var previousTranslationWidth: Double = 0.0

    func body(content: Content) -> some View {
        content
            .onAppear {
                position = initialPosition
            }
            .position(x: position.x, y: position.y)
            .offset(z: position.z)

            // Enable people to move the model anywhere in their space.
//            .simultaneousGesture(DragGesture(minimumDistance: 0.0, coordinateSpace: .global)
//                .handActivationBehavior(.pinch)
//                .onChanged { value in
//                    if let startPosition {
//                        let delta = value.location3D - value.startLocation3D
//                        position = startPosition + delta
//                    } else {
//                        startPosition = position
//                    }
//                }
//                .onEnded { _ in
//                    startPosition = nil
//                }
//            )

            // Enable people to scale the model within certain bounds.
            .simultaneousGesture(MagnifyGesture()
                .onChanged { value in
                    if let startScale {
                        scale = max(0.1, min(3, value.magnification * startScale))
                        self.globeEntity?.update(scale: SIMD3<Float>(repeating: Float(scale)))
                    } else {
                        startScale = scale
                    }
                }
                .onEnded { value in
                    startScale = scale
                }
            )
            
            // Enable model rotation
            .simultaneousGesture(
                DragGesture(minimumDistance: 0.0)
                    .onChanged { value in
                        let deltaTranslation = value.translation.width - previousTranslationWidth
                        // Update the previous translation width for the next frame
                        previousTranslationWidth = value.translation.width
                        
                        // Multiplier can be adjusted as needed
                        let rotationAmount = Float(deltaTranslation) * 0.01
                        
                        // Create a rotation quaternion around the Y axis
                        let rotation = simd_quatf(angle: rotationAmount, axis: SIMD3<Float>(0, 1, 0))
                        
                        // Apply rotation to the entity
                        self.globeEntity?.rotate(rotation: rotation)
                    }
                    .onEnded { _ in
                        // Reset the previous translation width at the end of the gesture
                        previousTranslationWidth = 0.0
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
