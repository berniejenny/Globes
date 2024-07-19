//
//  GlobesGridView.swift
//  Globes
//
//  Created by Bernhard Jenny on 4/5/2024.
//

import SwiftUI

struct GlobesGridView: View {
    @Environment(ViewModel.self) private var model
    
    let globes: [Globe]
    
    @ScaledMetric private var scaledGlobeSelectionViewHeight = GlobeSelectionView.viewHeight
    @ScaledMetric(relativeTo: .headline) private var scaledGlobeSelectionViewMinWidth = GlobeSelectionView.viewMinWidth
    
    var body: some View {
        let columns = [GridItem(.adaptive(minimum: scaledGlobeSelectionViewMinWidth))]
        
        GeometryReader { outer in
            ScrollViewReader { value in
                ScrollView(.vertical) {
                    LazyVGrid(columns: columns) {
                        ForEach(globes) { globe in
                            GeometryReader { inner in
                                let visibleFraction = CGRect.verticalInsideFraction(inner.frame(in: .global), outer.frame(in: .global))
                                GlobeSelectionView(globe: globe, visibleFraction: visibleFraction)
                            }
                            .frame(height: scaledGlobeSelectionViewHeight)
                            .padding(8)
                        }
                    }
                    .scrollTargetLayout() // for scrollTargetBehavior
                    .padding(.vertical)
                }
                .onChange(of: model.scrollGalleryToGlobe) {
                    Task { @MainActor in
                        if let globeId = model.scrollGalleryToGlobe {
                            model.scrollGalleryToGlobe = nil
                            withAnimation {
                                value.scrollTo(globeId)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .scrollTargetBehavior(.viewAligned) // align views with border of scroll view
            .scrollIndicators(.never)
        }
    }
}

#if DEBUG
#Preview {
    GlobesGridView(globes: Globe.previewGlobes)
}
#endif
