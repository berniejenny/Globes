//
//  Lighting.swift
//  Globes
//
//  Created by Bernhard Jenny on 7/6/2024.
//

import Foundation

enum Lighting: String, CaseIterable, Identifiable, CustomStringConvertible {
    case natural, lamps, even
    
    var id: Self { self }
    
    var description: String {
        switch self {
        case .natural:
            "Real-World Lighting"
        case .lamps:
            "Virtual Lamps"
        case .even:
            "Even Lighting"
        }
    }
    
    var info: String {
        switch self {
        case .natural:
            "The light of the real world illuminates the globes. Not available when a panorama is shown."
        case .lamps:
            "Virtual lamps illuminate the globes."
        case .even:
            "The globes are evenly lit from all directions."
        }
    }
    
    var imageBasedLightingTexture: String? {
        switch self {
        case .natural:
            nil
        case .lamps:
            "Lamps"
        case .even:
            "White"
        }
    }
}
