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
    
    let globe: Globe
    
    private static let globeViewSize: CGFloat = 100
    private static let height = 1.1 * globeViewSize
    private let cornerRadius: CGFloat = 20
    
    /// Radius of preview globe in meter
#warning("This could be derived from the view geometry size")
    private let globeRadius: Float = 0.035
    
    var body: some View {
        ZStack(alignment: .leading) {
            // name and author
            VStack(alignment: .leading) {
                Text(globe.name)
                    .font(.title3)
                if !globe.authorAndDate.isEmpty {
                    Text(globe.authorAndDate)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading)
            
            HStack {
                Spacer()
                
                ImmersiveGlobeView(
                    configuration: GlobeEntity.Configuration(
                        globe: globe,
                        position: [globeRadius, -globeRadius, globeRadius], // [x: to right, y: upwards, z: toward camera], relative to top-left view corner in scene coordinates
                        speed: 0.3,
                        usePreviewTexture: true,
                        addHoverEffect: false // hover effect on the globe is potentially confusing, because the background changes color when the globe is hovered.
                    ),
                    overrideRadius: globeRadius
                )
                .frame(width: Self.globeViewSize, height: Self.globeViewSize)
                .scaledToFit()
            }
        }
        
        .frame(height: Self.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        .hoverEffect()
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
        .onTapGesture {
            let configuration = GlobeEntity.Configuration(
                globe: globe,
                position: [globe.radius, globe.radius, -(globe.radius + 0.5)],
                speed: 0.1,
                isPaused: false,
                usePreviewTexture: false,
                enableGestures: true,
                addHoverEffect: false
            )
            model.selectedGlobeConfiguration = configuration
        }
    }
}

#if DEBUG
#Preview {
    GlobeSelectionView(globe: Globe.preview)
        .environment(ViewModel.preview)
}
#endif
