//
//  PanoramaImmersionStyle.swift
//  Globes
//
//  Created by Bernhard Jenny on 23/5/2024.
//

import SwiftUI

enum PanoramaImmersionStyle: String, CustomStringConvertible, CaseIterable {
    case progressive, full
    
    var immersionStyle: ImmersionStyle {
        switch self {
        case .progressive:
                .progressive
        case .full:
                .full
        }
    }
    
    var description: String {
        switch self {
        case .progressive:
            "Progressive"
        case .full:
            "Full 360°"
        }
    }
    
    var info: String {
        switch self {
        case .progressive:
            "An immersive panorama is only partially hiding the real world. Adjust the level of immersion by rotating the crown button."
        case .full:
            "A 360°-panorama is completely hiding the real world."
        }
    }
}
