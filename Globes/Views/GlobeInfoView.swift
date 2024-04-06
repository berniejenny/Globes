//
//  GlobeInfoView.swift
//  Globes
//
//  Created by Bernhard Jenny on 10/3/2024.
//

import SwiftUI

/// View with information about the selected globe, and an ornament to close the globe, rescale the globe and toggle rotation.
struct GlobeInfoView: View {
    @Environment(ViewModel.self) private var model
    
    var body: some View {
        if let globe = model.selectedGlobeConfiguration?.globe {            
            VStack(spacing: 20) {
                Text(globe.name)
                    .font(.title)
                if !globe.authorAndDate.isEmpty {
                    Text(globe.authorAndDate)
                        .font(.callout)
                }
                if let description = globe.description {
                    ScrollView(.vertical) {
                        Text(description)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: 400)
                    .padding(.horizontal)
                }
                if let infoURL = globe.infoURL {
                    let label = infoURL.absoluteString.contains("davidrumsey.com") ? "Open David Rumsey Map Collection Webpage" : "Open Webpage"
                    Button("More Information") {
                        model.webURL = infoURL
                    }
                    .help(label)
                    .controlSize(.small)
                    .padding(.bottom)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    GlobeInfoView()
        .padding(60)
        .glassBackgroundEffect()
        .environment(ViewModel.previewWithSelectedGlobe)
}
#endif
