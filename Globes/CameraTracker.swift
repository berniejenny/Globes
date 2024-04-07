//
//  CameraTracker.swift
//  Globes
//
//  Created by Bernhard Jenny on 24/3/2024.
//

import ARKit
import RealityKit
import SwiftUI

/// Current camera properties.
public final class CameraTracker {
    
    /// Camera tracking seems to require a moment to boot up. Call `start()` once when the app starts to initialize camera tracking.
    static func start() {
        let _ = shared
    }
    
    private init() {
        Task {
            do {
                try await arkitSession.run([worldTrackingProvider])
            } catch {
                fatalError("Cannot observe camera position: \(error)")
            }
        }
    }
    
    deinit {
        arkitSession.stop()
    }
    
    private let arkitSession = ARKitSession()
    private let worldTrackingProvider = WorldTrackingProvider()
    
    // MARK: - Camera properties
    
    /// The current position of the camera in world coordinate space in meter.
    public var position: SIMD3<Float> {
        guard let deviceAnchor = worldTrackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return SIMD3<Float>.zero
        }
        let cameraTransform = Transform(matrix: deviceAnchor.originFromAnchorTransform)
        let cameraPosition = cameraTransform.translation
        return cameraPosition
    }
    
    // MARK: - Singleton Accessor
    
    /// Retrieves the shared instance.
    static let shared = CameraTracker()
}
