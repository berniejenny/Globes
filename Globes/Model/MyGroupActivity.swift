//
//  MyGroupActivity.swift
//  Globes
//
//  Created by BooSung Jung on 19/7/2024.
//

import Foundation
import GroupActivities
struct MyGroupActivity: GroupActivity {
    var state: GlobeState = GlobeState(rotation: 0.0, zoom: 1.0)
    
    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = NSLocalizedString("Explore Together", comment: "Title of group activity")
        metadata.type = .generic
        
        return metadata
    }
}

struct GlobeState: Codable {
    var rotation: Double
    var zoom: Double
}

