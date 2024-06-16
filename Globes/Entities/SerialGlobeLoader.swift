//
//  SerialGlobeLoader.swift
//  Globes
//
//  Created by Bernhard Jenny on 12/6/2024.
//

import AsyncAlgorithms
import RealityKit
import SwiftUI

/// A singleton to load globe and panorama textures resources serially. Serial loading instead of concurrent loading reduces the chances of out-of-memory errors
/// when multiple textures are loaded and mipmaps generated. Uses Apple's Async Algorithms package for serializing asynchronous tasks.
/// Inspired by: https://stackoverflow.com/a/72353209
actor SerialGlobeLoader {
    
    /// Load a globe, a panorama or a globe model and texture for an animated globe.
    enum GlobeDestination: Equatable {
        case globe
        case panorama
        /// entityID: id of the animated globe entity
        case animation(entityID: UInt64)
    }
    
    /// The shared singleton.
    static let shared = SerialGlobeLoader()
    
    /// Queue for globes to load consisting of tuples of a globe and a destination.
    private let queue = AsyncChannel<(globe: Globe, destination: GlobeDestination)>()
    
    private init() {
        Task { await start() }
    }
    
    /// Add a globe to an internal queue to load serially.
    /// - Parameter globe: The globe to load.
    func load(globe: Globe) async {
        await queue.send((globe: globe, destination: .globe))
    }
    
    /// Add a globe for an animation to an internal queue to load serially.
    /// - Parameters:
    ///   - globe: The globe to load.
    ///   - animatedGlobeID: The id of the globe entity that will be partially replaced by the loaded globe. Not the globeId, because this will change.
    func load(globe: Globe, for animatedGlobeID: UInt64) async {
        await queue.send((globe: globe, destination: .animation(entityID: animatedGlobeID)))
    }
    
    /// Add a panorama globe to an internal queue to load serially.
    /// - Parameter panorama: The panorama globe to load.
    func load(panorama: Globe) async {
        await queue.send((globe: panorama, destination: .panorama))
    }
    
    /// A continuously running function that sequentially loads globes and panoramas in the `queue`.
    private func start() async {
        for await next in queue {
            do {
                guard ResourceLoader.hasSufficientMemoryToLoadTexture() else {
                    throw error("There is not enough memory.")
                }
                switch next.destination {
                case .globe:
                    let globeEntity = try await GlobeEntity(globe: next.globe)
                    Task { @MainActor in
                        ViewModel.shared.storeGlobeEntity(globeEntity)
                    }
                case .panorama:
                    let panoramaEntity = try await PanoramaEntity(globe: next.globe)
                    Task { @MainActor in
                        ViewModel.shared.storePanoramaEntity(panoramaEntity)
                    }
                case .animation(let entityID):
                    let globeEntity = try await GlobeEntity(globe: next.globe)
                    Task { @MainActor in
                        ViewModel.shared.storeAnimatedGlobe(globeEntity, entityID: entityID)
                    }
                }
            } catch {
                Task { @MainActor in
                    switch next.destination {
                    case .globe, .animation:
                        ViewModel.shared.loadingGlobeFailed(id: next.globe.id)
                    case .panorama:
                        ViewModel.shared.loadingPanoramaFailed()
                    }
                }
            }
        }
    }
}
