//
//  Registration.swift
//  Globes
//
//  Created by BooSung Jung on 31/7/2024.
//

import LinkPresentation
enum Registration {
    
    /// configures and registers the group activity to the apple Goup Activity Api
    static func registerGroupActivity() {
        let itemProvider = NSItemProvider()
        
#if DEBUG
        itemProvider.registerGroupActivity(MyGroupActivity().groupActivity)
        
#else
        itemProvider.registerGroupActivity(MyGroupActivity())
        
#endif
        
        let configuration = UIActivityItemsConfiguration(itemProviders: [itemProvider])
        configuration.metadataProvider = { key in
            guard key == .linkPresentationMetadata else { return }
            
#if DEBUG
            let metadata = MyGroupActivity().groupActivity.metadata
            
#else
            let metadata = LPLinkMetadata()
            metadata.title = String(localized: "Share Globes")
#endif
     
      
            return metadata
        }
        
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first?
            .rootViewController?
            .activityItemsConfiguration = configuration
    }
}
