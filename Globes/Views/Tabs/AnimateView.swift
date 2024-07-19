//
//  AnimateView.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/6/2024.
//

import SwiftUI

struct AnimateView: View {
    @Environment(ViewModel.self) var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpaceAction
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize: DynamicTypeSize
    
    @State private var selection = GlobeSelection.all
    
    @AppStorage("AnimationUniformSize")  private var animationUniformSize = true
    @AppStorage("AnimationRandomOrder") private var animationRandomOrder = false
    @AppStorage("AnimationInterval") private var animationInterval: Double = 3
    
    @ScaledMetric private var scaledGlobeViewWidth = GlobeView.viewWidth
    @ScaledMetric private var scaledGlobeViewHeight = GlobeView.viewHeight
    
    private let selections: [GlobeSelection] = [.all, .favorites, .earth, .celestial, .moon, .planets]
    
    var body: some View {
        NavigationSplitView {
            sidebar
            .padding()
            .navigationTitle("Animate")
        } detail: {
            let columns = [GridItem(.adaptive(minimum: scaledGlobeViewWidth))]
            
            GeometryReader { outer in
                ScrollViewReader { value in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: columns) {
                            ForEach(model.filteredGlobes(selection: selection)) { globe in
                                GeometryReader { inner in
                                    let visibleFraction = CGRect.verticalInsideFraction(inner.frame(in: .global), outer.frame(in: .global))
                                    GlobeView(globe: globe, visibleFraction: visibleFraction)
                                }
                                .frame(height: scaledGlobeViewHeight)
                            }
                        }
                        .scrollTargetLayout() // for scrollTargetBehavior
                    }
                    .padding()
                    .navigationBarHidden(true)
                    .clipped()
                    .scrollTargetBehavior(.viewAligned) // align views with border of scroll view
                    .scrollIndicators(.never)
                    .animation(.default, value: selection)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .ornament(attachmentAnchor: .scene(.top), contentAlignment: .bottom) {
            HStack {
                ForEach(selections) { selection in
                    Toggle(isOn: binding(for: selection)) {
                        Label(selection.rawValue.localizedCapitalized, systemImage: selection.systemImage)
                    }
                    .toggleStyle(.button)
                    .help(selection.help)
                }
            }
            .padding()
            .glassBackgroundEffect()
            .padding()
        }
    }
    
    @MainActor
    @ViewBuilder private var sidebar: some View {
        VStack {
            Button(action: loadAnimatedGlobe, label: {
                Image(systemName: "play")
            })
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .padding(.bottom, 40)
            
            HStack {
                Text("Change After \(Int(animationInterval.rounded())) Seconds")
                    .monospacedDigit()
                    .padding(.leading)
                Spacer(minLength: 0)
            }
            
            Slider(value: $animationInterval, in: 3...30)
                .padding(.bottom, 20)
            
            Group {
                Toggle(isOn: $animationUniformSize) {
                    // no icon when accessibility text size is large
                    if dynamicTypeSize.isAccessibilitySize {
                        Text("Uniform Size")
                    } else {
                        Label("Uniform Size", systemImage: "circle.circle")
                    }
                }
                
                Toggle("Random Order", isOn: $animationRandomOrder)
                    .padding(.vertical)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private func binding(for selection: GlobeSelection) -> Binding<Bool> {
        Binding (
            get: { selection == self.selection },
            set: { selected in
                if selected {
                    self.selection = selection
                }
            })
    }
    
    @MainActor
    private func loadAnimatedGlobe() {
        // Once loaded, a large texture will occupy about 350+ MB of memory.
        // Make sure there is sufficient memory to load the following texture.
        let reserve: UInt64 = 380 * 1024 * 1024
        guard ResourceLoader.hasSufficientMemoryToLoadTexture(reservedMemory: reserve) else {
            model.loadingGlobeFailed(id: nil)
            return
        }
        guard let globe = model.filteredGlobes(selection: selection).first else { return }
        model.load(
            globe: globe.copyWithNewId,
            selection: selection,
            openImmersiveSpaceAction: openImmersiveSpaceAction
        )
    }

}

#if DEBUG
#Preview {
    AnimateView()
        .environment(ViewModel.preview)
//        .frame(width: 800)
        .glassBackgroundEffect()
}
#endif
