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
    
    private var globe: Globe { model.selectedGlobeConfiguration?.globe ?? Globe() }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(globe.name)
                .font(.title)
            if !globe.authorAndDate.isEmpty {
                Text(globe.authorAndDate)
                    .font(.headline)
            }
            if let description = globe.description {
                ScrollView(.vertical) {
                    Text(description)
                        .multilineTextAlignment(.leading)
                }
            }
            if let infoURL = globe.infoURL {
                let label = infoURL.absoluteString.contains("davidrumsey.com") ? "Open David Rumsey Map Collection Webpage" : "Open Webpage"
                Link(label, destination: infoURL)
                    .padding(.bottom)
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            ornamentView
                .padding()
                .glassBackgroundEffect()
        }
    }
    
    private var isPausedBinding: Binding<Bool> {
        Binding(get: {
            model.selectedGlobeConfiguration?.isRotationPaused == true
        }, set: {
            model.selectedGlobeConfiguration?.isRotationPaused = $0
        })
    }
    
    @ViewBuilder private var ornamentView: some View {
        let globeIsScaled = model.selectedGlobeConfiguration?.globeEntity?.globeScale != 1
        
        HStack {
            Button(action: hideGlobe) {
                Label("Hide Globe", systemImage: "chevron.backward")
                    .labelStyle(.iconOnly)
            }
            .padding()
            .help("Hide the Globe")
            
            Button(action: resetGlobeScale) {
                Label("Reset Size", systemImage: "circle.circle")
                    .labelStyle(.iconOnly)
            }
            .disabled(!globeIsScaled)
            .padding()
            .help(globeIsScaled ? "Reset to Original Size" : "The Globe is at its Original Size")
            
            Toggle(isOn: isPausedBinding) {
                if isPausedBinding.wrappedValue {
                    Label("Rotate Globe", image: "arrow.counterclockwise.slash")
                } else {
                    Label("Rotate Globe", systemImage: "arrow.counterclockwise")
                }
                    
            }
            .labelStyle(.iconOnly)
            .toggleStyle(.button)
            .padding()
            .help(isPausedBinding.wrappedValue ? "Start Globe Rotation" : "Stop Globe Rotation")
        }
    }
    
    private func hideGlobe() {
#warning("Animation of globe visibility not working")
        withAnimation(.easeInOut(duration: 0.5)) {
            model.selectedGlobeConfiguration = nil
        }
    }
    
    private func resetGlobeScale() {
#warning("Animation of globe scale not working")
        withAnimation(.easeInOut(duration: 2)) {
            model.selectedGlobeConfiguration?.globeEntity?.globeScale = 1
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
