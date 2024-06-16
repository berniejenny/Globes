//
//  CollisionSound.swift
//  Globes
//
//  Created by Bernhard Jenny on 16/6/2024.
//

import Foundation

enum CollisionSound: String, CaseIterable, Identifiable {
    case none, glass, fabric, wood
    
    var id: Self { self }
    
    static var defaultSound: CollisionSound { .glass }
    
    /// Files are from Apple's 'Creating a Spaceship game' sample project
    /// https://developer.apple.com/documentation/realitykit/creating-a-spaceship-game
    var soundFileName: String? {
        switch self {
        case .none:
            nil
        case .glass:
            "Plastic_Glass_3"
        case .fabric:
            "Plastic_Fabric_2"
        case .wood:
            "Plastic_Wood_1"
        }
    }
}
