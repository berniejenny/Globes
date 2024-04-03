//
//  CreateYourOwnGlobeView.swift
//  Globes
//
//  Created by Bernhard Jenny on 27/3/2024.
//

import SwiftUI

struct CreateYourOwnGlobeView: View {
    @Environment(ViewModel.self) private var model
    
    @Binding var globe: Globe
    
    @State private var showingFileImporter = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text(globe.name)
                .font(.title)
            VStack {
                Text("Load an image with a 2:1 aspect ratio for the globe surface.")
                Button(action: {
                    showingFileImporter = true
                }) {
                    Label("Load Image", systemImage: "photo")
                }
                .onChange(of: showingFileImporter) {
                    DispatchQueue.main.async {
                        model.hidePreviewGlobes = showingFileImporter
                    }
                }
                
                Button(action: {
                    showingFileImporter = true
                }) {
                    Label("Generate Globe", systemImage: "globe")
                }
                
            }
            .padding()
//            if !globe.authorAndDate.isEmpty {
//                Text(globe.authorAndDate)
//                    .font(.callout)
//            }
//            if let description = globe.description {
//                ScrollView(.vertical) {
//                    Text(description)
//                        .multilineTextAlignment(.leading)
//                }
//                .frame(maxWidth: 400)
//                .padding(.horizontal)
//            }
//            if let infoURL = globe.infoURL {
//                let label = infoURL.absoluteString.contains("davidrumsey.com") ? "Open David Rumsey Map Collection Webpage" : "Open Webpage"
//                Button("More Information") {
//                    model.webURL = infoURL
//                }
//                .help(label)
//                .controlSize(.small)
//                .padding(.bottom)
//            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                globe.textureURL = url
            case .failure(let error):
                // handle error
                print(error)
            }
       }
    }
}

#if DEBUG
#Preview {
    let viewModel = ViewModel()
    viewModel.selectedGlobeConfiguration = .init(globe: Globe.preview)
    return CreateYourOwnGlobeView(globe: .constant(Globe.defaultCustomGlobe))
        .padding(60)
        .glassBackgroundEffect()
        .environment(viewModel)
}
#endif
