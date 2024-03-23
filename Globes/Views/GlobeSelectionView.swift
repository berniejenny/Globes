//
//  GlobeSelectionView.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/3/2024.
//

import RealityKit
import SwiftUI

/// A view with name, author and 3D model for a globe
struct GlobeSelectionView: View {
    
    /// The view model contains the currently selected globe.
    @Environment(ViewModel.self) private var model
    
    /// The globe that can be selected by pinching this view
    @State private var configuration: GlobeEntity.Configuration
    
    /// Flag to show progress view while loading large globe texture
    @State private var loadingTexture = false
    
    private static let globeViewSize: CGFloat = 100
    private static let height = 1.1 * globeViewSize
    private let cornerRadius: CGFloat = 20
    
    /// Radius of preview globe in meter
#warning("This could be derived from the view geometry size")
    // https://developer.apple.com/wwdc23/10080
    private let globeRadius: Float = 0.035
    
    init(globe: Globe) {
        self.configuration = GlobeEntity.Configuration(
            globe: globe,
            position: [globeRadius, -globeRadius, globeRadius], // [x: to right, y: upwards, z: toward camera], relative to top-left view corner in scene coordinates
            speed: 0.3,
            usePreviewTexture: true,
            addHoverEffect: false // hover effect on the globe is potentially confusing, because the background changes color when the globe is hovered.
        )
    }
        
    var body: some View {
        let authorAndDate = configuration.globe.authorAndDate
        
        ZStack(alignment: .leading) {
            // name and author
            VStack(alignment: .leading) {
                Text(configuration.globe.name)
                    .font(.headline)
                Text(authorAndDate)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .opacity(authorAndDate.isEmpty ? 0 : 1)
            }
            .padding(.leading)
            
            HStack {
                Spacer()
                ProgressView()
                    .padding()
                    .glassBackgroundEffect()
                Spacer()
            }
            .offset(z: 20)
            .opacity(loadingTexture ? 1 : 0)
            
            HStack {
                Spacer()
                
                ImmersiveGlobeView(configuration: configuration, overrideRadius: globeRadius)
                    .frame(width: Self.globeViewSize, height: Self.globeViewSize)
                    .scaledToFit()
                    .onChange(of: model.hidePreviewGlobes) {
                        DispatchQueue.main.async {
                            configuration.opacity = model.hidePreviewGlobes ? 0 : 1
                        }
                    }
            }
        }
        .frame(height: Self.height)
        .background(.regularMaterial.opacity(globeIsSelected ? 0 : 1), in: RoundedRectangle(cornerRadius: cornerRadius))
        .hoverEffect(isEnabled: !globeIsSelected)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
        .onTapGesture(perform: loadGlobe)
    }
    
    
    /// True if the globe that can be selected by this view is already selected.
    private var globeIsSelected: Bool {
        model.selectedGlobeConfiguration?.globe.id == configuration.globe.id
    }
    
    /// Async loading of globe.
    private func loadGlobe() {
        guard !globeIsSelected else { return }
        
        // create a new configuration if there is no selected globe
        let r = configuration.globe.radius
        if model.selectedGlobeConfiguration == nil {
            model.selectedGlobeConfiguration = GlobeEntity.Configuration(
                globe: configuration.globe,
                position: [r, r, -(r + 0.5)],
                speed: 0.1,
                isPaused: false,
                usePreviewTexture: false,
                enableGestures: true,
                addHoverEffect: false
            )
        }
        
        Task {
            if let selectedGlobeConfiguration = model.selectedGlobeConfiguration {
                withAnimation {
                    loadingTexture = true
                }
                // replace the globe metadata, but reuse other settings, such as position, rotation, etc.
                selectedGlobeConfiguration.globe = configuration.globe
                
                // load the globe
                selectedGlobeConfiguration.globeEntity = try await GlobeEntity(configuration: selectedGlobeConfiguration)
                withAnimation {
                    loadingTexture = false
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    GlobeSelectionView(globe: Globe.preview)
        .environment(ViewModel.preview)
}
#endif
