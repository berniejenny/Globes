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
    
    @State private var isSelected = false
    
    @MainActor
    private var showLoadingProgress: Bool {
        model.configurations[globe.id]?.isLoading == true
    }
    
    var body: some View {
        ZStack {
            Toggle(isOn: $isSelected, label: {
                ButtonImage(name: "globe")
                    .foregroundColor(isSelected ? .accentColor : .primary)
            })
            .toggleStyle(ButtonToggleStyle())
            .buttonStyle(.plain)
            .opacity(showLoadingProgress ? 0.05 : 1) // don't completely hide the button otherwise focus jumps to a neighboring button while the globe is loaded
            
            ProgressView()
                .controlSize(.mini)
                .opacity(showLoadingProgress ? 1 : 0)
        }        
        .onChange(of: isSelected) {
            Task { @MainActor in
                if isSelected {
                    await isSelected = model.show(globe: globe, openImmersiveSpaceAction: openImmersiveSpaceAction)
                } else {
                    model.hideGlobe(with: globe.id)
                }
            }
        }
        .onChange(of: model.configurations.keys) {
            Task { @MainActor in
                isSelected = model.configurations[globe.id] != nil
            }
        }
        .onChange(of: model.favorites, initial: true) {
            Task { @MainActor in
                isSelected = model.configurations[globe.id] != nil
            }
        }
    }
}
