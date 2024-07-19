//
//  GlobeView.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/6/2024.
//

import RealityKit
import SwiftUI

/// A view showing a 3D globe with name, author and date.
struct GlobeView: View {
    @Environment(ViewModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) var openImmersiveSpaceAction
    
    let globe: Globe
    
    static let viewWidth = 155.0
    static let viewHeight = 160.0
    
    @ScaledMetric private var scaledViewWidth = viewWidth
    @ScaledMetric private var scaledViewHeight = viewHeight
    @ScaledMetric private var scaledGlobeViewSize = 90.0
    
    private let cornerRadius = 20.0
    
    /// Value between 0 and 1 indicting the fraction of the view that is currently visible.
    /// This is used to sink the preview globe into the view if the view is not fully visible.
    var visibleFraction: Double
    
    @MainActor
    private var showLoadingProgress: Bool {
        model.configurations[globe.id]?.isLoading == true
    }
    
    @MainActor
    @ViewBuilder
    private var name: some View {
        let name = Text(globe.shortName ?? globe.name)
        if model.hasConfiguration(for: globe.id) {
            Text("● ").foregroundColor(.accentColor) + name
        } else {
            name
        }
    }
    
    var body: some View {
        VStack {
            ZStack {
                ImmersivePreviewGlobeView(globe: globe, rotate: true, addHoverEffect: true)
                    .frame(width: scaledGlobeViewSize, height: scaledGlobeViewSize)
                    .scaledToFit()
                    .offset(z: globeZOffset)
                    .animation(.default, value: model.hidePreviewGlobes)
                    .onTapGesture(perform: showGlobe)
                
                ProgressView()
                    .tint(.black)
                    .controlSize(.small)
                    .opacity(showLoadingProgress ? 1 : 0)
                    .offset(z: globeZOffset * 2 + 10)
            }
            .offset(y: -2)
            
            Spacer(minLength: 0)
            
            name
            Text(globe.author)
                .foregroundStyle(.secondary)
                .opacity(globe.author.isEmpty == true ? 0 : 1)
            Text(globe.date ?? "")
                .foregroundStyle(.secondary)
                .opacity(globe.date?.isEmpty == true ? 0 : 1)
        }
        .font(.caption)
        .allowsTightening(true)
        .padding(4)
        .frame(width: scaledViewWidth, height: scaledViewHeight)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    @MainActor
    private var globeZOffset: Double {
        if model.hidePreviewGlobes {
            -scaledGlobeViewSize * 0.6
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
#Preview {
    GlobeView(globe: Globe.preview, visibleFraction: 1)
        .environment(ViewModel.preview)
}
#endif
