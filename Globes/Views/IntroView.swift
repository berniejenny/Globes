//
//  IntroView.swift
//  Globes
//
//  Created by Bernhard Jenny on 20/3/2024.
//

import SwiftUI

/// Sidebar with title and information about the app.
struct IntroView: View {
    @Environment(ViewModel.self) private var model
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Globes")
                .font(.title)
                .padding(.top)
            Text("David Rumsey Map Center, Stanford Libraries")
                .foregroundStyle(.secondary)
                .font(.callout)
            Spacer()
            
            Group {
                Text("Choose a globe from the list.")
                Text("To position the globe, pinch and drag with one hand.")
                Text("To resize the globe, pinch and drag with both hands.")
                Text("To rotate the globe, pinch with one hand, hold for a moment and then drag. Or, pinch and rotate with both hands.")
                Text("Double-pinch to stop and start the automatic rotation.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack {
                Spacer()
                Menu {
                    Button("About Globes…") {
                        model.showingAboutSheet.toggle()
                    }
                    Divider()
                    Link(destination: AppStore.writeReviewURL) {
                        Text("Review Globes on the App Store")
                    }
                    Divider()
                    Link(destination: URL(string: "https://www.davidrumsey.com")!) {
                        Text("Visit David Rumsey Map Collection in Safari")
                    }
                } label: {
                    Label("Options", systemImage: "ellipsis")
                }
                .labelStyle(.iconOnly)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal)
        .sheet(isPresented: Bindable(model).showingAboutSheet) {
            AboutView()
        }
    }
}

#if DEBUG
#Preview(windowStyle: .automatic) {
    IntroView()
        .environment(ViewModel.preview)
    
}
#endif
