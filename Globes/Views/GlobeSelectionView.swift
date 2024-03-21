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
    @Environment(ViewModel.self) private var model
        
    @State private var configuration: GlobeEntity.Configuration
    
    private static let globeViewSize: CGFloat = 100
    private static let height = 1.1 * globeViewSize
    private let cornerRadius: CGFloat = 20
    
    /// Radius of preview globe in meter
#warning("This could be derived from the view geometry size")
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
    
    private var globe: Globe { configuration.globe }
    
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        .hoverEffect()
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
        .onTapGesture {
            if model.selectedGlobeConfiguration == nil {
                model.selectedGlobeConfiguration = GlobeEntity.Configuration(
                    globe: globe,
                    position: [globe.radius, globe.radius, -(globe.radius + 0.5)],
                    speed: 0.1,
                    isPaused: false,
                    usePreviewTexture: false,
                    enableGestures: true,
                    addHoverEffect: false
                )
            } else {
                Task {
                    if let configuration = model.selectedGlobeConfiguration {
                        configuration.globe = globe
                        configuration.globeEntity = await GlobeEntity(configuration: configuration)
                    }
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
