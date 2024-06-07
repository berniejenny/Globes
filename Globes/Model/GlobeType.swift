//
//  GlobeType.swift
//  Globes
//
//  Created by Bernhard Jenny on 7/6/2024.
//

import Foundation

enum GlobeType: String, Codable, CaseIterable {
    case earth
    case celestial
    case moon
    case planet
    case moonNonEarth
    
    var label: String {
        switch self {
        case .earth:
            return "Earth"
        case .celestial:
            return "Celestial"
        case .moon:
            return "Moon"
        case .planet:
            return "Planet Other than Earth"
        case .moonNonEarth:
            return "Moon of a Planet Other Than Earth"
        }
    }
}
