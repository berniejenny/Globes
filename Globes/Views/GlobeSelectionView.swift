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
    let globe: Globe
    
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
        self.globe = globe
        //        self.configuration = GlobeConfiguration(
        //            globe: globe,
        //            speed: GlobeConfiguration.defaultRotationSpeedForPreviewGlobes,
        //            usePreviewTexture: true,
        //            addHoverEffect: false // hover effect on the globe is potentially confusing, because the background changes color when the globe is hovered.
        //        )
    }
    
    var body: some View {
        let authorAndDate = globe.authorAndDate
        
        ZStack(alignment: .leading) {
            // name and author
            VStack(alignment: .leading) {
                Text(globe.name)
                    .font(.headline)
                Text(authorAndDate)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .opacity(authorAndDate.isEmpty ? 0 : 1)
            }
            .padding(.leading)
            
            // progress view
            HStack {
                Spacer()
                ProgressView()
                    .padding()
                    .glassBackgroundEffect()
                Spacer()
            }
            .offset(z: 20)
            .opacity(loadingTexture ? 1 : 0)
            
            // 3D preview globe
            HStack {
                Spacer()
                ImmersivePreviewGlobeView(
                    globe: globe,
                    opacity: model.hidePreviewGlobes ? 0 : 1,
                    radius: globeRadius
                )
                .frame(width: Self.globeViewSize, height: Self.globeViewSize)
                .scaledToFit()
                .offset(z: Self.globeViewSize / 2)
            }
        }
        .frame(height: Self.height)
        .background(.regularMaterial.opacity(globeIsSelected ? 0 : 1), in: RoundedRectangle(cornerRadius: cornerRadius))
        .hoverEffect(isEnabled: !globeIsSelected)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
        .onTapGesture(perform: loadGlobe)
    }
    
    /// True if the globe that can be selected by this view is selected.
    private var globeIsSelected: Bool {
        model.selectedGlobeConfiguration?.globe.id == globe.id
    }
    
    /// Async loading of globe.
    private func loadGlobe() {
        guard !globeIsSelected else { return }
        Task {
            withAnimation {
                loadingTexture = true
            }
            defer {
                withAnimation {
                    loadingTexture = false
                }
            }
            let configuration = GlobeConfiguration(
                globe: globe,
                speed: GlobeConfiguration.defaultRotationSpeed,
                adjustRotationSpeedToSize: true,
                isPaused: false,
                usePreviewTexture: false,
                enableGestures: true,
                addHoverEffect: false
            )
#warning("TBD: Handle error")
            try await model.loadGlobe(configuration: configuration)
        }
    }
}

#if DEBUG
#Preview {
    GlobeSelectionView(globe: Globe.preview)
        .environment(ViewModel.preview)
}
#endif
