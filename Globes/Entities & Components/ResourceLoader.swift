//
//  ResourceLoader.swift
//  Globes
//
//  Created by Bernhard Jenny on 7/5/2024.
//

import RealityKit
import SwiftUI

struct ResourceLoader {
    private init() {}
    
    static var canLoadAnotherGlobe: Bool {
        // 348 MB GPU
        // 350 to 385 MB PROC
        // estimated size in bytes of a 16k×8k RGBA texture
        let textureSize: UInt64 = 16384 * 8192 * 4
        // texture with mipmap, which increases the size by 1/3
        let mipmapTextureSize = textureSize * 4 / 3
        
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
        // Texture allocation and mipmap generation is wasteful as of visionOS 1.1.
        // Instruments shows that once the texture is loaded and uncompressed, two additional copies
        // of the size of the uncompressed texture are created while initializing the texture.
        // After initialization, the increase in allocated memory is about half of width×height×4,
        // which indicates that an efficient compression is used for textures.
        let availableProcMemory = os_proc_available_memory()
        return availableProcMemory > textureSize * 3
    }
    
    @MainActor
    private static func globeIsLoaded(_ globe: Globe, _ model: ViewModel) -> Bool {
        model.configurations[globe.id] != nil
    }
    
    /// Load a globe in an async task and run a move-in  animation
    @MainActor
    static func loadGlobe(globe: Globe, model: ViewModel) {
        guard !globeIsLoaded(globe, model) else { return }
        Task {
            do {
                var configuration = GlobeConfiguration(
                    radius: globe.radius,
                    speed: GlobeConfiguration.defaultRotationSpeed,
                    adjustRotationSpeedToSize: true,
                    isRotationPaused: !model.rotateGlobes
                )
                configuration.isLoading = true
                
                await MainActor.run {
                    model.configurations[globe.id] = configuration
                }

                // load the globe
                let globeEntity = try await GlobeEntity(globe: globe)
                
                await MainActor.run {
                    configuration.isLoading = false
                    
                    // Set the initial scale and position for a move-in animation.
                    globeEntity.scale = [0.01, 0.01, 0.01]
                    globeEntity.position = configuration.positionRelativeToCamera(distanceToGlobe: 2)
                    
                    // Rotate the central meridian to the camera, to avoid showing the empty hemisphere on the backside of some globes.
                    // The central meridian is at [-1, 0, 0], because the texture u-coordinate with lat = -180° starts at the x-axis.
                    if let viewDirection = CameraTracker.shared.viewDirection {
                        var orientation = simd_quatf(from: [-1, 0, 0], to: -viewDirection)
                        orientation = GlobeEntity.orientToNorth(orientation: globeEntity.orientation)
                        globeEntity.orientation = orientation
                    }
                                        
                    // compute target position before adding configuration and entity
                    let targetPosition = Self.targetPosition(model: model, configuration: configuration)
                    model.configurations[globe.id] = configuration
                    model.globeEntities[globe.id] = globeEntity
                    
                    // Start the move-in animation.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        globeEntity.animateTransform(scale: 1, position: targetPosition)
                        AppStore.increaseGlobesCount(promptReview: false)
                    }
                }
            } catch {
                await MainActor.run {
                    // Important: do not animate `loadingTexture` before the error dialog is shown.
                    // As of VisionOS 1.1, animating `loadingTexture` with `withAnimation { loadingTexture = false }`
                    // results in some preview globes not disappearing when the alert is shown.
                    // This seems to be a bug in VisionOS; it happens with alerts and sheets.

                    var configuration = model.configurations[globe.id]
                    configuration?.isLoading = false
                    model.configurations[globe.id] = configuration
                    model.errorToShowInAlert = error
                }
            }
        }
    }
    
    @MainActor
    /// Returns a  position for a new globe. Tries to find a position that does not result in intersections with existing globes.
    /// - Parameters:
    ///   - model: View model.
    ///   - configuration: Configuration of the new globe.
    /// - Returns: Position of the center of the globe.
    static func targetPosition(model: ViewModel, configuration: GlobeConfiguration) -> SIMD3<Float> {
        let targetPosition = configuration.positionRelativeToCamera(distanceToGlobe: 0.5)
        if model.canPlaceGlobe(at: targetPosition, with: configuration.radius) {
            return targetPosition
        }
        
        // search for a free position
        // local coordinate system with x-axis perpendicular to the viewing direction
        guard let cameraViewDirection = CameraTracker.shared.viewDirection else {
            return SIMD3(0, 1, 0)
        }
        let toCamera = cameraViewDirection * -1
        let rightAxis = SIMD3(toCamera.z, 0, -toCamera.x)
        let upAxis = cross(toCamera, rightAxis)
        
        // a few rotations in an Archimedean spiral
        let rotations = 10
        let spacing = configuration.radius + 0.1
        let b = spacing / (2 * .pi)
        // stretch the spiral horizontally and compress it vertically to position globes in a landscape format
        let stretch: Float = 1.5
        for alphaDeg in stride(from: 3, to: rotations * 360, by: 3) {
            let omega = Float(alphaDeg) / 180 * .pi
            let r = b * omega
            let x = cos(omega) * r * stretch
            let y = sin(omega) * r / stretch
            let candidatePosition = targetPosition + x * rightAxis + y * upAxis
            if model.canPlaceGlobe(at: candidatePosition, with: configuration.radius) {
                return candidatePosition
            }
        }
        
        // could not find an empty spot
        return targetPosition
    }
    
    /// Load a panorama
    @MainActor
    static func loadPanorama(globe: Globe, model: ViewModel) {
        guard model.panoramaGlobe?.id != globe.id else { return }
        
        guard ResourceLoader.canLoadAnotherGlobe else {
            model.errorToShowInAlert = error(
                "There is not enough memory to open a panorama.",
                secondaryMessage: "First hide another globe, then open this panorama again."
            )
            return
        }
        
        model.isLoadingPanorama = true
        model.panoramaGlobe = globe
        
        Task {
            do {                
                let panoramaEntity = try await PanoramaEntity(globe: globe)
                await MainActor.run {
                    model.isLoadingPanorama = false
                    model.panoramaEntity = panoramaEntity
                    AppStore.increaseGlobesCount(promptReview: false)
                }
            } catch {
                await MainActor.run {
                    model.isLoadingPanorama = false
                    model.panoramaEntity = nil
                    model.panoramaGlobe = nil
                    model.errorToShowInAlert = error
                }
            }
        }
    }
    
    @MainActor
    /// Load the globe material, including a texture.
    static func loadMaterial(globe: Globe, loadPreviewTexture: Bool, roughness: Float?, clearcoat: Float?) async throws -> RealityKit.Material {
        let textureResource = try await loadTexture(globe: globe, loadPreviewTexture: loadPreviewTexture)
        var material = PhysicallyBasedMaterial()
        material.baseColor.texture = MaterialParameters.Texture(textureResource, sampler: highQualityTextureSampler)
        
        // small roughness results in shiny reflection, large roughness results in matte appearance
        if let roughness {
            assert(roughness >= 0 && roughness <= 1, "Roughness out of bounds.")
            material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: roughness)
        }
        
        // simulate clear transparent coating between 0 (none) and 1
        if let clearcoat {
            assert(clearcoat >= 0 && clearcoat <= 1, "Clearcoat out of bounds.")
            material.clearcoat = .init(floatLiteral: clearcoat)
        }
        
        return material
    }
    
    /// Highest possible quality for mipmap texture sampling
    private static var highQualityTextureSampler: MaterialParameters.Texture.Sampler {
        let samplerDescription = MTLSamplerDescriptor()
        samplerDescription.maxAnisotropy = 16 // 16 is maximum number of samples for anisotropic filtering (default is 1)
        samplerDescription.minFilter = MTLSamplerMinMagFilter.linear // linear filtering (instead of nearest) when texture pixels are larger than rendered pixels
        samplerDescription.magFilter = MTLSamplerMinMagFilter.linear // linear filtering (instead of nearest) when texture pixels are smaller than rendered pixels
        samplerDescription.mipFilter = MTLSamplerMipFilter.linear // linear interpolation between mipmap levels
        return MaterialParameters.Texture.Sampler(samplerDescription)
    }
    
    @MainActor
    /// Load a texture resource from the app bundle (for full resolution) or the assets store (for preview globes).
    static func loadTexture(globe: Globe, loadPreviewTexture: Bool) async throws -> TextureResource {

#if targetEnvironment(simulator)
        // The visionOS simulator cannot handle 16k textures, so use the preview texture when running in the simulator.
        let loadPreviewTexture = true
#else
        let loadPreviewTexture = loadPreviewTexture
#endif
        
        let textureOptions = TextureResource.CreateOptions(semantic: .color, mipmapsMode: .allocateAndGenerateAll)
        if let textureURL = globe.textureURL {
            return try await loadExternalTexture(url: textureURL, textureOptions: textureOptions, preview: loadPreviewTexture)
        }
        
        if loadPreviewTexture {
            // load texture from assets
            return try await TextureResource(named: globe.previewTexture, options: textureOptions)
        } else {
            // load texture from image file in app bundle
            var url = Bundle.main.url(forResource: globe.texture, withExtension: "jpg")
            if url == nil {
                url = Bundle.main.url(forResource: globe.texture, withExtension: "heic")
            }
            guard let url else {
                fatalError("Cannot find \(globe.texture) with JPEG or HEIC format in the app bundle.")
            }
            return try await TextureResource(contentsOf: url, options: textureOptions)
        }
    }
    
    static private func loadExternalTexture(url: URL, textureOptions: TextureResource.CreateOptions, preview: Bool) async throws -> TextureResource {
        let gotAccess = url.startAccessingSecurityScopedResource()
        if !gotAccess {
            throw NSError(domain: "Load Texture", code: -1, userInfo: [NSLocalizedDescriptionKey: "The image cannot be loaded."])
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try await TextureResource(contentsOf: url, options: textureOptions)
    }
}
