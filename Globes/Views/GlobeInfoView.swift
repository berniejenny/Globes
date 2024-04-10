//
//  GlobeInfoView.swift
//  Globes
//
//  Created by Bernhard Jenny on 10/3/2024.
//

import SwiftUI

/// View with information about the selected globe.
struct GlobeInfoView: View {
    @Environment(ViewModel.self) private var model
    
    var body: some View {
        if let globe = model.selectedGlobeConfiguration?.globe {            
            VStack(spacing: 10) {
                Text(globe.name)
                    .font(.title)
                    .multilineTextAlignment(.center)
                
                if let nameTranslated = globe.nameTranslated, !nameTranslated.isEmpty {
                    Text(nameTranslated)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                }
                if let date = globe.date, !date.isEmpty {
                    Text(date)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                }
                if !globe.author.isEmpty {
                    Text(globe.author)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                }
                if let description = globe.description {
                    ScrollView(.vertical) {
                        Text(description)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: 400)
                    .padding()
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
