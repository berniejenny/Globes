//
//  MyGroupActivity.swift
//  Globes
//
//  Created by BooSung Jung on 19/7/2024.
//

import Foundation
import GroupActivities
import SwiftUI
import SharePlayMock

class MyGroupActivity: GroupActivityMock{
    typealias ActivityType = MyGroupActivity.AppGroupActivity
     
     private(set) var groupActivity: AppGroupActivity
    init() {
            self.groupActivity = AppGroupActivity()
        }
    struct AppGroupActivity: GroupActivity{

        // Define a unique activity identifier for system to reference
                static let activityIdentifier = "com.boosungjung.Globes.MyGroupActivity"
               
        var metadata: GroupActivityMetadata {
            var metadata = GroupActivityMetadata()
            metadata.title = "Globes SharePlay"
            metadata.subtitle = "Test Subtitle"

            metadata.type = .generic
            return metadata
        }
}
    
  
}

