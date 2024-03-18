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
            model.selectedGlobeConfiguration?.isPaused == true
        }, set: {
            model.selectedGlobeConfiguration?.isPaused = $0
        })
    }
    
    @ViewBuilder private var ornamentView: some View {
        @Bindable var model = model
        
        HStack {
            Button(action: hideGlobe) {
                Label("Hide Globe", systemImage: "chevron.backward")
                    .labelStyle(.iconOnly)
            }
            .padding()
            .help("Hide the Globe")
            
//            Button(action: resetGlobeSize) {
//                Label("Reset Size", systemImage: "circle.circle")
//                    .labelStyle(.iconOnly)
//            }
//            .padding()
//            .help("Reset to the Original Size")
            
            Toggle(isOn: isPausedBinding) {
                Label("Rotate Globe", systemImage: "arrow.counterclockwise")
                    .labelStyle(.iconOnly)
            }
            .toggleStyle(.button)
            .padding()
            .help(isPausedBinding.wrappedValue ? "Rotate the Globe" : "Pause Globe Rotation")
            
//            Button(action: resetGlobeOrientation) {
//                Label("Orient Globe", systemImage: "location.north")
//                    .labelStyle(.iconOnly)
//            }
//            .padding()
//            .help("Orient the Globe")
        }
    }
    
    private func hideGlobe() {
        withAnimation(.easeInOut(duration: 0.5)) {
            model.selectedGlobeConfiguration = nil
        }
    }
    
    private func resetGlobeSize() {
        withAnimation(.easeInOut(duration: 1)) {
#warning("TBD: reset scale of globe")
            model.selectedGlobeConfiguration?.scale = 1
        }
    }
    
    private func resetGlobeOrientation() {
        withAnimation(.easeInOut(duration: 1)) {
#warning("TBD: reset axis of rotation of globe such that north is on top")
            model.selectedGlobeConfiguration?.rotation = .init(angle: 0, axis: [0, 1, 0])
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
