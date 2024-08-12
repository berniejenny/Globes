//
//  ActivityState.swift
//  Globes
//
//  Created by BooSung Jung on 31/7/2024.
//

import CoreFoundation

struct ActivityState: Codable, Equatable {
    var mode: Mode = .localOnly
    var globeConfigurations: [Globe.ID: GlobeConfiguration] = [:]
    var globeEntities: [Globe.ID: GlobeEntity] = [:]

}
