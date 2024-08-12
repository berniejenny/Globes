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
        itemProvider.registerGroupActivity(MyGroupActivity().groupActivity)
        
        let configuration = UIActivityItemsConfiguration(itemProviders: [itemProvider])
        configuration.metadataProvider = { key in
            guard key == .linkPresentationMetadata else { return nil}
            let metadata = LPLinkMetadata()
            metadata.title = String(localized: "Share planet")
//            metadata.imageProvider = NSItemProvider(object: UIImage(resource: .birdicon))
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
