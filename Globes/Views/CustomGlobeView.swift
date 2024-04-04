//
//  CreateYourOwnGlobeView.swift
//  Globes
//
//  Created by Bernhard Jenny on 27/3/2024.
//

import SwiftUI

struct CustomGlobeView: View {
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
                loadGlobe(textureURL: url)
            case .failure(let error):
                // handle error
#warning("TBD: Handle error")
                print(error)
            }
       }
    }
    
    private func loadGlobe(textureURL: URL) {
        Task {
            globe.textureURL = textureURL
            let configuration = GlobeConfiguration(
                globe: globe,
                speed: GlobeConfiguration.defaultRotationSpeed,
                adjustRotationSpeedToSize: true,
                enableGestures: true
            )
#warning("TBD: Handle error")
            try await model.loadGlobe(configuration: configuration)
        }
    }
}

#if DEBUG
#Preview {
    let viewModel = ViewModel()
    Task {
        try await viewModel.loadGlobe(configuration: .init(globe: Globe.preview))
    }
    return CustomGlobeView(globe: .constant(Globe.defaultCustomGlobe))
        .padding(60)
        .glassBackgroundEffect()
        .environment(viewModel)
}
#endif
