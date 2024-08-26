//
//  ActivityState.swift
//  Globes
//
//  Created by BooSung Jung on 31/7/2024.
//
import CoreFoundation
import Foundation
import RealityFoundation

/// VisionPro A will have its own globeConfiguration and for every change it will record what the change is and the globeConfiguration in the activityState. This information will be passed down to VisionPro B which will gather this information and
/// apply the changes accordingly. This will work with more players too.
///
///
struct ActivityState: Codable, Equatable {
    var changes: [Globe.ID: GlobeChange] = [:]
    var sharedGlobeConfiguration: [Globe.ID: GlobeConfiguration] = [:]
    
    #warning("for some reason Transform crashes the app for Vision Pro versions < 2.0, which is why i am using my own TempTranslation")
    var tempTranslation:TempTranslation?
}

enum GlobeChange: String, Codable, Equatable, CaseIterable {
    case load
    case hide
    case resize
    case transform
    case rotate
    case none
}

struct TempTranslation: Codable, Equatable {
    var scale: Float?
    var orientation: simd_quatf?
    var position: SIMD3<Float>?
    var duration: Double?

    init(scale: Float? = nil, orientation: simd_quatf? = nil, position: SIMD3<Float>? = nil, duration: Double? = 0) {
        self.scale = scale
        self.orientation = orientation
        self.position = position
        self.duration = duration
    }

    // Custom Codable implementation
    enum CodingKeys: String, CodingKey {
        case scale
        case orientation
        case position
        case duration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scale = try container.decodeIfPresent(Float.self, forKey: .scale)
        position = try container.decodeIfPresent(SIMD3<Float>.self, forKey: .position)
        
        if let orientationArray = try container.decodeIfPresent([Float].self, forKey: .orientation), orientationArray.count == 4 {
            orientation = simd_quatf(ix: orientationArray[0], iy: orientationArray[1], iz: orientationArray[2], r: orientationArray[3])
        } else {
            orientation = nil
        }
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(scale, forKey: .scale)
        try container.encodeIfPresent(position, forKey: .position)
        
        if let orientation = orientation {
            let orientationArray = [orientation.imag.x, orientation.imag.y, orientation.imag.z, orientation.real]
            try container.encode(orientationArray, forKey: .orientation)
        }
        try container.encodeIfPresent(duration, forKey: .duration)
    }
}
