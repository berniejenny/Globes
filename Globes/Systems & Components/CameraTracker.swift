//
//  CameraTracker.swift
//  Globes
//
//  Created by Bernhard Jenny on 24/3/2024.
//

import ARKit
import os
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
                Logger().log("Started ARKitSession")
            } catch {
                fatalError("Cannot observe camera position: \(error)")
            }
        }
    }
    
    private let arkitSession = ARKitSession()
    private let worldTrackingProvider = WorldTrackingProvider()
    
    // MARK: - Camera properties
    
    /// The transform from the device to the origin coordinate system.
    private var cameraTransform: Transform? {
        guard WorldTrackingProvider.isSupported else {
            Logger().error("Camera tracking is not supported.")
            return nil
        }
        guard worldTrackingProvider.state == .running,
              let deviceAnchor = worldTrackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }
        return Transform(matrix: deviceAnchor.originFromAnchorTransform)
    }
    
    /// The current position of the camera in world coordinate space in meter. Returns nil if there is no open immersive space.
    public var position: SIMD3<Float>? {
        cameraTransform?.translation
    }
    
    /// The unary direction vector pointing from the camera in the direction of view in the world coordinate space. Returns nil if there is no open immersive space.
    public var viewDirection: SIMD3<Float>? {
        cameraTransform?.rotation.act(SIMD3(0, 0, -1))
    }
    
    // MARK: - Singleton Accessor
    
    /// The shared instance.
    static let shared = CameraTracker()
}
