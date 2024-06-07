//
//  WebViewDecorated.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/4/2024.
//

import SwiftUI

/// A `WebView` for displaying a webpage .
struct WebViewDecorated: View {
    let url: URL
    
    @State private var webViewStatus: WebViewStatus = .loading
    
    var body: some View {
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
    }
}

#if DEBUG
#Preview(windowStyle: .automatic) {
    WebViewDecorated(url: URL(string: "https://apple.com")!)
        .environment(ViewModel.preview)
}
#endif
