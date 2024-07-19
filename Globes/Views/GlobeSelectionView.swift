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
        
    static let viewHeight: Double = 136
    static let viewMinWidth: Double = 320
    @ScaledMetric private var scaledViewHeight = Self.viewHeight
    @ScaledMetric(relativeTo: .headline) private var scaledMinWidth = Self.viewMinWidth
    @ScaledMetric private var scaledGlobeViewSize: Double = 100
    @ScaledMetric private var scaledButtonPaddingH = 4
    @ScaledMetric private var scaledButtonPaddingV = 8
    
    private let cornerRadius: Double = 20

    /// Value between 0 and 1 indicting the fraction of the view that is currently visible.
    /// This is used to sink the preview globe into the view if the view is not fully visible.
    var visibleFraction: Double
    
    var body: some View {
        ZStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 3) {
                Text(globe.date ?? "")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                ViewThatFits {
                    Text(globe.name)
                    Text(globe.shortName ?? globe.name)
                }
                .font(.headline)
                .padding(.trailing, scaledGlobeViewSize)
                
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
                    .padding(.vertical, scaledButtonPaddingV)
                    .padding(.horizontal, scaledButtonPaddingH)
                    Spacer()
                }
            }
            .padding(.trailing, scaledGlobeViewSize / 2)
            
            // 3D preview globe
            HStack {
                Spacer()
                ImmersivePreviewGlobeView(globe: globe, rotate: true)
                    .frame(width: scaledGlobeViewSize, height: scaledGlobeViewSize)
                    .scaledToFit()
                    .offset(z: globeZOffset)
                    .animation(.default, value: model.hidePreviewGlobes)
                    .padding(.trailing, 10)
                    .onTapGesture(perform: showGlobe)
            }
        }
        .frame(height: scaledViewHeight)
        .frame(minWidth: scaledMinWidth)
        .allowsTightening(true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    @MainActor
    private var globeZOffset: Double {
        if model.hidePreviewGlobes {
            -scaledGlobeViewSize * 0.55
        } else {
            scaledGlobeViewSize * 0.5 * (visibleFraction * visibleFraction * visibleFraction * visibleFraction * 2 - 1)
        }
    }
    
    @MainActor
    private func showGlobe() {
        model.load(globe: globe, openImmersiveSpaceAction: openImmersiveSpaceAction)
    }
}

#if DEBUG
#Preview(windowStyle: .automatic) {
    GlobeSelectionView(globe: Globe.editablePreview, visibleFraction: 1)
        .environment(ViewModel.preview)
        .padding()
}
#endif
