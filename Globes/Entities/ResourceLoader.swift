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
