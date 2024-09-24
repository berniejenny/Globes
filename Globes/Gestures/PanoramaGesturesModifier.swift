//
//  PanoramaGesturesModifier.swift
//  Globes
//
//  Created by Bernhard Jenny on 25/5/2024.
//

import ARKit
import os
import RealityKit
import SwiftUI

extension View {
    /// Adds gestures for rotating a panorama around its vertical axis.
    @MainActor
    func panoramaGestures(model: ViewModel) -> some View {
            if let panoramaEntity = model.panoramaEntity {
                return AnyView(self.modifier(PanoramaGesturesModifier(model: model)))
            } else {
                return AnyView(self)
            }
        }
    }

/// A modifier that adds a drag gesture for rotating a panorama around its vertical axis.
@MainActor
private struct PanoramaGesturesModifier: ViewModifier {
    
    /// The orientation at the start of the drag gesture.
    @State private var  orientationAtGestureStart: simd_quatf? = nil
    
    /// Immersion style at the start of the drag gesture
    @State private var immersionStyleAtGestureStart: PanoramaImmersionStyle = .progressive
    
    let model: ViewModel
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(dragGesture)
    }
   
    /// Drag gesture to rotate the globe.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0.0)
            .targetedToEntity(model.panoramaEntity ?? Entity())
            .handActivationBehavior(.automatic) // allow for globes being pushed when the hand or a finger intersects it
            .onChanged { value in
                Task { @MainActor in
                    if orientationAtGestureStart == nil {
                        log("start panorama drag")
                        orientationAtGestureStart = value.entity.orientation(relativeTo: nil)
                        immersionStyleAtGestureStart = model.panoramaImmersionStyle
                        model.panoramaImmersionStyle = .progressive
                    }
                    
                    if let orientationAtGestureStart,
                       let cameraPosition = CameraTracker.shared.position {
                        log("update panorama drag")
                        let location3D = value.convert(value.location3D, from: .local, to: .scene)
                        let startLocation3D = value.convert(value.startLocation3D, from: .local, to: .scene)
                        var v1 = startLocation3D - cameraPosition
                        var v2 = location3D - cameraPosition
                        v1.y = 0
                        v2.y = 0
                        v1 = normalize(v1)
                        v2 = normalize(v2)
                        let rotation = simd_quatf(from: v1, to: v2)
                        model.panoramaEntity?.orientation = simd_mul(orientationAtGestureStart, rotation)
                    }
                }
            }
            .onEnded { _ in
                log("end panorama drag")
                orientationAtGestureStart = nil
                model.panoramaImmersionStyle = immersionStyleAtGestureStart
            }
    }
    
    private func log(_ message: String) {
#if DEBUG
        let logger = Logger(subsystem: "Globe Gestures", category: "Gestures")
        logger.info("\(message)")
#endif
    }
}

