//
//  ActivityState.swift
//  Globes
//
//  Created by BooSung Jung on 31/7/2024.
//

import CoreFoundation

#warning("only share transform not entities")
#warning("share configuration")
struct ActivityState: Codable, Equatable {
    var globeConfigurations: [Globe.ID: GlobeConfiguration] = [:]
    var globeEntities: [Globe.ID: GlobeEntity] = [:]
}
