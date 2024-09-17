//
//  Registration.swift
//  Globes
//
//  Created by BooSung Jung on 31/7/2024.
//

import LinkPresentation
enum Registration {
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
            metadata.title = String(localized: "Register: Share planet Release")
#endif
            #warning("add image")
            //            metadata.imageProvider = NSItemProvider(object: UIImage(resource: .shareplay))
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
