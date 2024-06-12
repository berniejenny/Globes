//
//  GlobeSelection.swift
//  Globes
//
//  Created by Bernhard Jenny on 9/6/2024.
//

import Foundation

enum GlobeSelection: String, Hashable, CaseIterable, Identifiable {
    case all, favorites, earth, celestial, moon, planets, custom, none
    
    var id: Self { self }
    
    var systemImage: String {
        switch self {
        case .all:
            "globe"
        case .favorites:
            "heart"
        case .earth:
            "globe.europe.africa.fill"
        case .celestial:
            "sparkles"
        case .moon:
            "moon.fill"
        case .planets:
            "circle"
        case .custom:
            "hammer.fill"
        case .none:
            "xmark"
        }
    }
    
    var help: String {
        switch self {
        case .all:
            "All Globes"
        case .favorites:
            "Favorites"
        case .earth:
            "Terrestrial Globes"
        case .celestial:
            "Star Constellations in the Sky"
        case .moon:
            "Earth’s Moon"
        case .planets:
            "Planets and their Moons"
        case .custom:
            "Custom Globes"
        case .none:
            "None"
        }
    }
}
