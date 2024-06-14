//
//  ImageBasedLightSourceEntity.swift
//  Globes
//
//  Created by Bernhard Jenny on 11/5/2024.
//

import os
import RealityKit
import SwiftUI

class ImageBasedLightSourceEntity: Entity {
    
    @MainActor required init() {
        super.init()
    }
    
    /// Returns nil if `texture` is nil.
    /// - Parameters:
    ///   - texture: The name of the image based lighting texture resource.
    ///   - intensity: Intensity exponent.
    init?(texture: String?, intensity: Float) async {
        super.init()
        if let texture {
            await load(texture: texture, intensity: intensity)
        } else {
            return nil
        }
    }
    
    func load(texture: String, intensity: Float) async {
        guard let resource = try? await EnvironmentResource(named: texture) else {
            Logger().error("Image based lighting resource not found.")
            return
        }
        let iblComponent = ImageBasedLightComponent(
            source: .single(resource),
            intensityExponent: intensity)
        
        // Ensure that the light rotates with its entity. Omit this line
        // for a light that remains fixed relative to the surroundings.
        // iblComponent.inheritsRotation = true
        
        self.components.set(iblComponent)
    }
}
