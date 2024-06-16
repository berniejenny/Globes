//
//  GlobeButton.swift
//  Globes
//
//  Created by Bernhard Jenny on 5/5/2024.
//

import SwiftUI

struct GlobeButton: View {
    @Environment(ViewModel.self) private var model
    @Environment(\.openImmersiveSpace) var openImmersiveSpaceAction
    
    let globe: Globe
    
    @State private var bounceDownTrigger = 0
    
    @MainActor
    private var globeExists: Bool {
        model.hasConfiguration(for: globe.id)
    }
    
    @MainActor
    private var globeBinding: Binding<Bool> { Binding (
        get: { globeExists },
        set: { showOrHideGlobe($0) }
    )}
    
    @MainActor
    private var showLoadingProgress: Bool {
        model.configurations[globe.id]?.isLoading == true
    }
    
    var body: some View {
        ZStack {
            Toggle(isOn: globeBinding, label: {
                ButtonImage(name: "globe")
                    .foregroundColor(globeExists ? .accentColor : .primary)
            })
            .symbolEffect(.bounce.down, value: bounceDownTrigger)
            .toggleStyle(ButtonToggleStyle())
            .buttonStyle(.plain)
            .opacity(showLoadingProgress ? 0.05 : 1) // don't completely hide the button otherwise focus jumps to a neighboring button while the globe is loaded
            
            ProgressView()
                .controlSize(.mini)
                .opacity(showLoadingProgress ? 1 : 0)
        }
    }
    
    @MainActor
    private func showOrHideGlobe(_ show: Bool) {
        Task { @MainActor in
            if show {
                model.load(globe: globe, openImmersiveSpaceAction: openImmersiveSpaceAction)
            } else {
                model.hideGlobe(with: globe.id)
                bounceDownTrigger += 1
            }
        }
    }
}
