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
    
    @State private var editGlobe = false
    
    private let globeViewSize: Double = 90
    private let viewHeight: Double = 160
    private let viewWidth: Double = 155
    private let cornerRadius: Double = 20
    
    /// Radius of preview globe in meter
    private let globeRadius: Float = 0.038
    
    /// Value between 0 and 1 indicting the fraction of the view that is currently visible.
    /// This is used to sink the preview globe into the view if the view is not fully visible.
    var visibleFraction: Double = 1
    
    @MainActor
    private var showLoadingProgress: Bool {
        model.configurations[globe.id]?.isLoading == true
    }
    
    @MainActor
    @ViewBuilder
    private var name: some View {
        let name = Text(globe.shortName ?? globe.name)
        if model.configurations.keys.contains(globe.id) {
            Text("● ").foregroundColor(.accentColor) + name
        } else {
            name
        }
    }
    
    var body: some View {
        VStack {
            ZStack {
                ImmersivePreviewGlobeView(globe: globe, rotate: true, addHoverEffect: true, radius: globeRadius)
                    .frame(width: globeViewSize, height: globeViewSize)
                    .scaledToFit()
                    .offset(z: globeZOffset)
                    .animation(.default, value: model.hidePreviewGlobes)
                    .onTapGesture(perform: showGlobe)
                
                ProgressView()
                    .controlSize(.small)
                    .padding(4)
                    .glassBackgroundEffect()
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
        .frame(height: viewHeight)
        .frame(width: viewWidth)
//        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    @MainActor
    private var globeZOffset: Double {
        if model.hidePreviewGlobes {
            -globeViewSize * 0.6
        } else {
            globeViewSize * 0.5 * (visibleFraction * visibleFraction * visibleFraction * visibleFraction * 2 - 1)
        }
    }
    
    private func showGlobe() {
        Task { @MainActor in
            let _ = await model.show(globe: globe, openImmersiveSpaceAction: openImmersiveSpaceAction)
        }
    }
}

#if DEBUG
#Preview {
    GlobeView(globe: Globe.preview)
        .environment(ViewModel.preview)
}
#endif