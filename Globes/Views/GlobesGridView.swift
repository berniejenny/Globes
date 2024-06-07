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
        
    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 450))]
        
        GeometryReader { outer in
            ScrollViewReader { value in
                ScrollView(.vertical) {
                    LazyVGrid(columns: columns) {
                        ForEach(globes) { globe in
                            GeometryReader { inner in
                                let visibleFraction = visibleFraction(inner.frame(in: .global), outer.frame(in: .global))
                                GlobeSelectionView(globe: globe, visibleFraction: visibleFraction)
                            }
                            .frame(height: 130)
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

    /// Computes a value between 0 and 1 indicating the fraction of an `inner` frame that is inside an `outer` frame.
    /// - Parameters:
    ///   - innerFrame: Inner frame
    ///   - outerFrame: Outer frame
    /// - Returns: Value between 0 and 1.
    private func visibleFraction(_ innerFrame: CGRect, _ outerFrame: CGRect) -> Double {
        var visibleFraction: Double = 1
        if innerFrame.maxY > outerFrame.maxY {
            // inner frame is partially outside the outer frame at the bottom
            visibleFraction = (outerFrame.maxY - innerFrame.minY) / innerFrame.height
        } else if innerFrame.minY < outerFrame.minY {
            // at the top
            visibleFraction = Double(innerFrame.minY / innerFrame.height) + 1
        }
        return min(max(visibleFraction, 0), 1)
    }
}

#if DEBUG
#Preview {
    GlobesGridView(globes: Globe.previewGlobes)
}
#endif
