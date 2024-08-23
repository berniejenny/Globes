//
//  GroupActivity.swift
//  VisionSharePlayTest
//
//  Created by BooSung Jung on 30/7/2024.
//

import GroupActivities
import SwiftUI
import SharePlayMock

#if DEBUG
class MyGroupActivity: GroupActivityMock {
    
    typealias ActivityType = MyGroupActivity.Activity
    
    private(set) var groupActivity: Activity
    
    init() {
        self.groupActivity = Activity()
    }
    
    struct Activity: GroupActivity {
        
        static let activityIdentifier = "com.davidrumseymapcollection.globes"
        
        var metadata: GroupActivityMetadata {
            var metadata = GroupActivityMetadata()
            metadata.title = "Group activity: Globes Debug"
            metadata.subtitle = "Let's explore together!"
            metadata.sceneAssociationBehavior = .content("planet") // we associate it with a behaviour so we prioritise the content
            metadata.previewImage = UIImage(resource: .shareplay).cgImage
            metadata.type = .generic
            return metadata
        }
    }
}
#else
struct MyGroupActivity: GroupActivity {
    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "Group activity: Globes Release"
        metadata.subtitle = "Let's explore together!"
        metadata.sceneAssociationBehavior = .content("planet")
        metadata.previewImage = UIImage(resource: .shareplay).cgImage
        
        metadata.type = .generic
        
        return metadata
    }
}
#endif
