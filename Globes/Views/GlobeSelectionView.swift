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
    private static let viewHeight = 1.1 * globeViewSize
    private let cornerRadius: CGFloat = 20
    
    /// Radius of preview globe in meter
#warning("This could be derived from the view geometry size")
    // https://developer.apple.com/wwdc23/10080 at 14:45
    private let globeRadius: Float = 0.035
    
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
                ImmersivePreviewGlobeView(globe: globe, radius: globeRadius)
                .frame(width: Self.globeViewSize, height: Self.globeViewSize)
                .scaledToFit()
                .offset(z: Self.globeViewSize / 2)
            }
        }
        .frame(height: Self.viewHeight)
        .background(.regularMaterial.opacity(globeIsSelected ? 0 : 1), in: RoundedRectangle(cornerRadius: cornerRadius))
        .hoverEffect(isEnabled: !globeIsSelected)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
        .onTapGesture(perform: loadGlobe)
    }
    
    /// True if the globe that can be selected by this view is selected.
    @MainActor
    private var globeIsSelected: Bool {
        model.selectedGlobeConfiguration?.globe.id == globe.id
    }
    
    /// Load the globe in an async task.
    private func loadGlobe() {
        Task {
            do {
                await MainActor.run {
                    // avoid loading the globe if it already exists
                    guard !globeIsSelected else { return }
                    
                    // show progress view
                    withAnimation { loadingTexture = true }
                }
                
                // load the globe
                let globeEntity = try await GlobeEntity(globe: globe)
                
                await MainActor.run {
                    let configuration = GlobeConfiguration(
                        globe: globe,
                        speed: GlobeConfiguration.defaultRotationSpeed,
                        adjustRotationSpeedToSize: true,
                        isPaused: false
                    )
                    configuration.position(relativeTo: model.selectedGlobeConfiguration)
                    configuration.globeEntity = globeEntity
                    model.selectedGlobeConfiguration = configuration
                    
                    withAnimation { loadingTexture = false }
                }
                
            } catch {
                await MainActor.run {
                    // Important: do not animate `loadingTexture` before the error dialog is shown.
                    // As of VisionOS 1.1, animating `loadingTexture` with `withAnimation { loadingTexture = false }`
                    // results in some preview globes not disappearing when the alert is shown.
                    // This seems to be a bug in VisionOS, as it appears with alerts and sheets.
                    loadingTexture = false
                    model.errorToShowInAlert = error
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
