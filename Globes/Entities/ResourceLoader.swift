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
    
    /// Test whether there is sufficient process memory and GPU memory for loading an ARGB texture image with the load functions of `TextureResource` and creating a mipmap.
    /// - Parameters:
    ///   - width: Width of the texture.
    ///   - height: Height of the texture.
    ///   - reservedMemory: Amount of memory in bytes that is not currently allocated but should be considered allocated. This test always considers a 250 MB reserve; `reservedMemory` is added to this reserve.
    /// - Returns: True if a texture with the passed dimensions can be loaded using the load functions of `TextureResource` with the currently available memory.
    static func hasSufficientMemoryToLoadTexture(width: Int = 16384, height: Int = 8192, reservedMemory: UInt64 = 0) -> Bool {
#if targetEnvironment(simulator)
        return true
#else
        // estimated size in bytes of the RGBA texture
        let textureSize = UInt64(width * height * 4)
        // mipmap increases the size by 1/3
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
        // Texture allocation and mipmap generation is wasteful as of visionOS 1.2.
        // Instruments shows that once the texture is loaded and uncompressed, two additional copies
        // of the size of the uncompressed texture are created while initializing the texture.
        // After initialization, the increase in allocated memory is about half of width×height×4,
        // which indicates that an efficient compression is used for textures.
        // 250 MB memory reserve
        let memoryReserve: UInt64 = 250 * 1024 * 1024 + reservedMemory
        let availableProcMemory = os_proc_available_memory()
        return availableProcMemory > textureSize * 3 + memoryReserve
#endif
    }
    
    @MainActor
    /// Load a globe material, including a texture, and create a high-quality mipmap.
    ///
    /// Creating mipmaps requires a lot of memory. To avoid out-of-memory errors that terminate the app, the `SerialGlobeLoader` should be used instead when loading large textures.
    /// - Parameters:
    ///   - globe: The globe
    ///   - loadPreviewTexture: If true, a small texture image is loaded from the asset catalogue.
    ///   - roughness: Roughness index of the material between 0 and 1.  A small roughness results in shiny reflection, large roughness results in a matte appearance.
    ///   - clearcoat: Simulate clear transparent coating between 0 (none) and 1.
    /// - Returns: A physically based material.
    static func loadMaterial(globe: Globe, loadPreviewTexture: Bool, roughness: Float?, clearcoat: Float?) async throws -> PhysicallyBasedMaterial {
        let textureResource = try await loadTexture(globe: globe, loadPreviewTexture: loadPreviewTexture)
        var material = PhysicallyBasedMaterial()
        material.baseColor.texture = MaterialParameters.Texture(textureResource, sampler: highQualityTextureSampler)
        
        if let roughness {
            assert(roughness >= 0 && roughness <= 1, "Roughness out of bounds.")
            material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: roughness)
        }
        
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
    private static func loadTexture(globe: Globe, loadPreviewTexture: Bool) async throws -> TextureResource {
        
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
    
    private static func loadExternalTexture(url: URL, textureOptions: TextureResource.CreateOptions, preview: Bool) async throws -> TextureResource {
        let gotAccess = url.startAccessingSecurityScopedResource()
        if !gotAccess {
            throw NSError(domain: "Load Texture", code: -1, userInfo: [NSLocalizedDescriptionKey: "The image cannot be loaded."])
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try await TextureResource(contentsOf: url, options: textureOptions)
    }
}
