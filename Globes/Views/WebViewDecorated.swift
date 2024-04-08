//
//  WebViewDecorated.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/4/2024.
//

import SwiftUI

/// A `WebView` for displaying a webpage about the currently selected globe.
struct WebViewDecorated: View {
    @Environment(ViewModel.self) var model
    @State private var webViewStatus: WebViewStatus = .loading
    
    var body: some View {
        let url = model.webURL ?? URL(string: "https://www.davidrumsey.com")!
        
        ZStack {
            WebView(url: url, status: $webViewStatus)
            
            switch webViewStatus {
            case .loading:
                ProgressView("Loading Page")
                    .padding()
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
            case .finishedLoading:
                EmptyView()
            case .failed(let error):
                VStack {
                    Text("The page could not be loaded.")
                    Text(error.localizedDescription)
                }
                .padding()
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            HStack {
                Button(action: {
                    model.webURL = nil
                }) {
                    Label("Go Back to Globes", systemImage: "chevron.left")
                }
                .labelStyle(.iconOnly)
                .help("Go Back to Globes")
                .padding()
                
                Link("Open in Safari", destination: url)
                    .padding()
            }
            .glassBackgroundEffect()
        }
    }
}

#if DEBUG
#Preview(windowStyle: .automatic) {
    WebViewDecorated()
        .environment(ViewModel.preview)
}
#endif
