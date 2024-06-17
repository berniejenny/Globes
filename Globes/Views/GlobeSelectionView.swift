//
//  GlobeSelectionView.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/3/2024.
//

import RealityKit
import SwiftUI

/// A view to select a globe displaying name, author and 3D model of a globe.
struct GlobeSelectionView: View {
    let globe: Globe
    
    @Environment(ViewModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) var openImmersiveSpaceAction
    
    @State private var editGlobe = false
    
    private let globeViewSize: Double = 100
    private let viewHeight: Double = 130
    private let viewMinWidth: Double = 280
    private let cornerRadius: Double = 20
    
    /// Radius of preview globe in meter
#warning("This could be derived from the view geometry size")
    // https://developer.apple.com/wwdc23/10080 at 14:45
    private let globeRadius: Float = 0.035

    /// Value between 0 and 1 indicting the fraction of the view that is currently visible.
    /// This is used to sink the preview globe into the view if the view is not fully visible.
    var visibleFraction: Double
    
    var body: some View {
        ZStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 3) {
                Text(globe.date ?? "")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(globe.name)
                    .font(.headline)
                Text(globe.author)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.top)
            .padding(.leading)
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Group {
                        GlobeButton(globe: globe)
                        PanoramaButton(globe: globe)
                        FavoriteGlobeButton(globeId: globe.id)
                    }
                    .padding(8)
                    Spacer()
                }
            }
            .padding(.trailing, 50)
            
            // 3D preview globe
            HStack {
                Spacer()
                ImmersivePreviewGlobeView(globe: globe, rotate: true, radius: globeRadius)
                    .frame(width: globeViewSize, height: globeViewSize)
                    .scaledToFit()
                    .offset(z: globeZOffset)
                    .animation(.default, value: model.hidePreviewGlobes)
                    .padding(.trailing, 10)
                    .onTapGesture(perform: showGlobe)
            }
        }
        .frame(height: viewHeight)
        .frame(minWidth: viewMinWidth)
        .allowsTightening(true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    @MainActor
    private var globeZOffset: Double {
        if model.hidePreviewGlobes {
            -globeViewSize * 0.55
        } else {
            globeViewSize * 0.5 * (visibleFraction * visibleFraction * visibleFraction * visibleFraction * 2 - 1)
        }
    }
    
    private func showGlobe() {
        Task { @MainActor in
            let _ = await model.load(globe: globe, openImmersiveSpaceAction: openImmersiveSpaceAction)
        }
    }
}

#if DEBUG
#Preview {
    GlobeSelectionView(globe: Globe.editablePreview, visibleFraction: 1)
        .frame(width: 500)
        .environment(ViewModel.preview)
}
#endif
