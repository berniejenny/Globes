//
//  GlobesOptionsView.swift
//  Globes
//
//  Created by Bernhard Jenny on 23/5/2024.
//

import AVFoundation
import SwiftUI

struct SettingsView: View {
    @Environment(ViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    
    private let immersionStyles: [PanoramaImmersionStyle] = [.progressive, .full]
    private let globeViewSize: Double = 120
    private let globeRadius: Float = 0.05
    
    @State private var player: AVAudioPlayer?
    
    @AppStorage("CollisionSound") private var collisionSound = CollisionSound.fabric
    
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
                
                Toggle(isOn: Bindable(model).rotateGlobes) {
                    VStack(alignment: .leading) {
                        Label(title: { Text("Rotate Globes") },
                              icon: {
                                Image(model.rotateGlobes ? "rotate.3d" : "rotate.3d.slash")
                        })
                        .contentTransition(.symbolEffect(.replace))
                        
                        Text("Double-pinch a globe to start and stop its rotation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
                
                Picker(selection: $collisionSound) {
                    ForEach(CollisionSound.allCases) { collisionSound in
                        Text(collisionSound.rawValue.localizedCapitalized)
                        if collisionSound == .none {
                            Divider()
                        }
                    }
                } label: {
                    Label(
                        "Sound When Globes Touch",
                        systemImage: collisionSound == .none ? "speaker.slash" : "speaker.wave.2"
                    )
                    .contentTransition(.symbolEffect(.replace))
                }
                .padding(.vertical, 3)
                .onChange(of: collisionSound) {
                   playSound()
                }
            } header: {
                Text("Globes")
            }
            
            Section {
                VStack {
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
                }
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
    
    func playSound() {
        guard let fileName = collisionSound.soundFileName else {
            // without this test, the first sound in the bundle is loaded
            return
        }
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "aiff") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            Task { @MainActor in
                // wait until default sound effect of the picker is played
                try await Task.sleep(for: .seconds(0.4))
                player?.play()
            }
        } catch {
            Task { @MainActor in
                model.errorToShowInAlert = error
            }
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
