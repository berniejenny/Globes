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
    @State private var configuration: GlobeConfiguration
    
    /// Flag to show progress view while loading large globe texture
    @State private var loadingTexture = false
    
    private static let globeViewSize: CGFloat = 100
    private static let height = 1.1 * globeViewSize
    private let cornerRadius: CGFloat = 20
    
    /// Radius of preview globe in meter
#warning("This could be derived from the view geometry size")
    // https://developer.apple.com/wwdc23/10080 at 14:45
    private let globeRadius: Float = 0.035
    
    init(globe: Globe) {
        self.configuration = GlobeConfiguration(
            globe: globe,
            speed: GlobeConfiguration.defaultRotationSpeedForPreviewGlobes,
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
                
                ImmersivePreviewGlobeView(configuration: configuration, radius: globeRadius)
                    .frame(width: Self.globeViewSize, height: Self.globeViewSize)
                    .scaledToFit()
                    .onChange(of: model.hidePreviewGlobes) {
                        DispatchQueue.main.async {
                            configuration.opacity = model.hidePreviewGlobes ? 0 : 1
                        }
                    }
                    .offset(z: Self.globeViewSize / 2)
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
        
        Task {
            // create a new configuration if there is no selected globe
            if model.selectedGlobeConfiguration == nil {
                model.selectedGlobeConfiguration = GlobeConfiguration(
                    globe: configuration.globe,
                    speed: GlobeConfiguration.defaultRotationSpeed,
                    adjustRotationSpeedToSize: true,
                    isPaused: false,
                    usePreviewTexture: false,
                    enableGestures: true,
                    addHoverEffect: false
                )
            }
            
            if let selectedGlobeConfiguration = model.selectedGlobeConfiguration {
                withAnimation {
                    loadingTexture = true
                }
                defer {
                    withAnimation {
                        loadingTexture = false
                    }
                }
                
                // replace the globe metadata, but reuse other settings, such as rotation toggle.
                let oldRadius = selectedGlobeConfiguration.globe.radius // remember the radius
                selectedGlobeConfiguration.globe = configuration.globe
                
                // load the globe
                let newGlobe = try await GlobeEntity(configuration: selectedGlobeConfiguration)
                
                // position the new globe such that its closest part is at the same distance as the closest part of the current globe
                if let globeEntity = selectedGlobeConfiguration.globeEntity {
                    print("Reuse position for", configuration.globe.name)
                    // the position of the previous globe
                    let oldPosition = await globeEntity.position
                    // scaled radius of the globe
                    let oldScaledRadius = await oldRadius * globeEntity.uniformScale
                    // the new globe (with scale = 1) differs by this factor in size from the old globe
                    let oldScale = oldScaledRadius / configuration.globe.radius
                    await newGlobe.scaleAndAdjustDistanceToCamera(
                        newScale: 1,
                        oldScale: oldScale,
                        oldPosition: oldPosition,
                        globeRadius: configuration.globe.radius
                    )
                } else {
                    print("New position for", configuration.globe.name)
                    // position the globe in front of the camera
                    let r = configuration.globe.radius
                    let globeCenter = SIMD3<Float>([0, 1, -(r + 0.5)])
                    await newGlobe.setPosition(globeCenter, relativeTo: nil)
                    await print(newGlobe.position)
                }
                
                selectedGlobeConfiguration.globeEntity = newGlobe
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
