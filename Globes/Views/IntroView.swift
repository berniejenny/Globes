//
//  IntroView.swift
//  Globes
//
//  Created by Bernhard Jenny on 20/3/2024.
//

import SwiftUI

struct IntroView: View {
    @Environment(ViewModel.self) private var model
    @State private var showingAboutSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Harvard University Library")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Globes")
                .font(.title)
                .padding(.top)
            Text("David Rumsey Map Collection")
                .font(.callout)
            Spacer()
            
            Group {
                Text("Choose a globe from the list.")
                Text("Pinch and drag to position the globe.")
                Text("Pinch and hold for a moment, then drag to rotate the globe.")
                Text("Pinch and drag with both hands to resize the globe.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack {
                Spacer()
                Menu {
                    aboutButton
                    Divider()
                    Link(destination: URL(string: "https://www.davidrumsey.com")!) {
                        Label("Visit David Rumsey Map Collection in Safari", systemImage: "globe")
                            .labelStyle(.titleOnly)
                    }
                } label: {
                    Label("Options", systemImage: "ellipsis")
                }
                .labelStyle(.iconOnly)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingAboutSheet) {
            AboutView()
        }
    }
    
    @ViewBuilder private var aboutButton: some View {
        Button("About Globes…") {
            model.hidePreviewGlobes = true
            showingAboutSheet.toggle()
        }
        .onChange(of: showingAboutSheet) {
            DispatchQueue.main.async {
                model.hidePreviewGlobes = showingAboutSheet
            }
        }
    }
}

#if DEBUG
#Preview(windowStyle: .automatic) {
    IntroView()
        .environment(ViewModel.preview)
    
}
#endif
