//
//  GlobesOptionsView.swift
//  Globes
//
//  Created by Bernhard Jenny on 23/5/2024.
//

import SwiftUI

struct SettingsView: View {
    @Environment(ViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    
    private let immersionStyles: [PanoramaImmersionStyle] = [.progressive, .full]
    private let globeViewSize: Double = 120
    private let globeRadius: Float = 0.05
    
    var body: some View {
        Form {
            Section {
                Picker(selection: Bindable(model).lighting) {
                    ForEach(Lighting.allCases) { lighting in
                        Text(String(describing: lighting))
                            .disabled(lighting == .natural && model.isShowingPanorama)
                    }
                } label: {
                    if let previewGlobe {
                        ImmersivePreviewGlobeView(
                            globe: previewGlobe,
                            rotate: model.rotateGlobes,
                            radius: globeRadius
                        )
                            .frame(width: globeViewSize, height: globeViewSize)
                            .scaledToFit()
                            .padding([.top, .leading])
                            .offset(z: globeZOffset)
                            .animation(.default, value: model.hidePreviewGlobes)
                    }
                }
                .listRowSeparator(.hidden)
                
                Text(model.lighting.info)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Toggle("Rotate Globes", systemImage: "rotate.3d", isOn: Bindable(model).rotateGlobes)
                
                Text("Double-pinch a globe to start and stop its rotation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .offset(y: -20)
                    .listRowSeparator(.hidden)
            } header: {
                Text("Globes")
            }
            
            Section {
                Text("Immersion Mode")
                
                Picker("Panorama Immersion Mode", selection: Bindable(model).panoramaImmersionStyle) {
                    ForEach(immersionStyles, id: \.self) { immersionStyle in
                        Text(String(describing: immersionStyle))
                    }
                }
                .pickerStyle(.segmented)
                
                Text(model.panoramaImmersionStyle.info)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            } header: {
                Text("Panorama")
            }
            .listRowSeparator(.hidden)
        }
        .frame(maxWidth: 500)
        .padding(.top)
        .padding()
    }
    
    @MainActor
    private var previewGlobe: Globe? {
        if let id = model.configurations.first?.key,
           let globe = model.globes.first(where: { $0.id == id }){
            return globe
        }
        return model.globes.first(where: { $0.authorSurname == "Bellerby" })
    }
    
    @MainActor
    private var globeZOffset: Double {
        if model.hidePreviewGlobes {
            -globeViewSize * 0.55
        } else {
            globeViewSize * 0.5
        }
    }
}

#if DEBUG
#Preview {
    SettingsView()
        .padding()
        .glassBackgroundEffect()
        .environment(ViewModel.preview)
}
#endif
