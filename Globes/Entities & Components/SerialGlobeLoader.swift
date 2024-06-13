//
//  SerialGlobeLoader.swift
//  Globes
//
//  Created by Bernhard Jenny on 12/6/2024.
//

import AsyncAlgorithms
import RealityKit
import SwiftUI

enum GlobeDestination: Equatable {
    case globe
    case panorama
    case animation(entityID: UInt64)
}

/// A singleton to load texture resources serially. Serial loading instead of concurrent loading reduces the chances of out-of-memory errors
/// when multiple textures are loaded and mipmaps generated. Uses Apple's Async Algorithms package for serializing asynchronous tasks.
/// Inspired by: https://stackoverflow.com/a/72353209
actor SerialGlobeLoader {
    
    /// The shared singleton.
    static let shared = SerialGlobeLoader()
    
    /// Queue for globes to load.
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
                guard hasSufficientMemoryForLoadingGlobe else {
                    throw LoadingError()
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
                    break
                }
            } catch {
                Task { @MainActor in
                    let errorToShow = (error as? LoadingError)?.createError(isPanorama: next.destination == .panorama) ?? error
                    switch next.destination {
                    case .globe:
                        ViewModel.shared.loadingGlobeFailed(errorToShow, id: next.globe.id)
                    case .panorama:
                        ViewModel.shared.loadingPanoramaFailed(errorToShow)
                    case .animation:
                        ViewModel.shared.errorToShowInAlert = errorToShow
                    }
                }
            }
        }
    }
    
    private struct LoadingError: Error {
        @MainActor
        func createError(isPanorama: Bool) -> Error {
            if isPanorama {
                let isShowingPanorama = ViewModel.shared.isShowingPanorama
                return error("There is not enough memory to show this panorama.",
                             secondaryMessage: "First hide a globe \(isShowingPanorama ? "or the current panorama" : ""), then select the panorama again.")
            } else {
                return error("There is not enough memory to show another globe.",
                             secondaryMessage: "First hide a visible globe, then select this globe again.")
            }
        }
    }
    
    /// Test whether there is sufficient process memory and and GPU memory for loading a 16k×8k RGBA texture resource.
    private var hasSufficientMemoryForLoadingGlobe: Bool {
#if targetEnvironment(simulator)
        return true
#endif
        // 348 MB GPU
        // 350 to 385 MB PROC
        // estimated size in bytes of a 16k×8k RGBA texture
        let textureSize: UInt64 = 16384 * 8192 * 4
        // texture with mipmap, which increases the size by 1/3
        let mipmapTextureSize = textureSize * 4 / 3
        
        // 250 MB memory reserve
        let memoryReserve: UInt64 = 250 * 1024 * 1024
        
        // check available GPU memory
        if let defaultDevice = MTLCreateSystemDefaultDevice () {
            let allocatedGPU = UInt64(defaultDevice.currentAllocatedSize)
            let maxGPU = defaultDevice.recommendedMaxWorkingSetSize
            let availableGPU = maxGPU - allocatedGPU
            if availableGPU < mipmapTextureSize {
                return false
            }
        }
        
        // Check available process memory
        // Texture allocation and mipmap generation is wasteful as of visionOS 1.2.
        // Instruments shows that once the texture is loaded and uncompressed, two additional copies
        // of the size of the uncompressed texture are created while initializing the texture.
        // After initialization, the increase in allocated memory is about half of width×height×4,
        // which indicates that an efficient compression is used for textures.
        let availableProcMemory = os_proc_available_memory()
        return availableProcMemory > textureSize * 3 + memoryReserve
    }
}
