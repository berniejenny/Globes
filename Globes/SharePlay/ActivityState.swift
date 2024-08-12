//
//  ActivityState.swift
//  Globes
//
//  Created by BooSung Jung on 31/7/2024.
//

import CoreFoundation

// activity message that is going to be sent to the group
struct ActivityState: Codable {
    var enlarged: Bool = false
    var mode: Mode = .localOnly
}


extension ActivityState {
    mutating func clear() {
       
    }
}
