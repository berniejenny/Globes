//
//  PlayView.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/6/2024.
//

import SwiftUI

struct PlayView: View {
    @Environment(ViewModel.self) var model
    
    @State private var selection = GlobeSelection.all
    @State private var duration: Double = 5
    @State private var adjustSize = true
    
    private let selections: [GlobeSelection] = [.all, .favorites, .earth, .celestial, .moon, .planets]
    
    var body: some View {
        NavigationSplitView {
            VStack {
                Button(action: {}, label: {
                    Label("Play", systemImage: "play")
                        .labelStyle(.iconOnly)
                })
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .padding(.bottom, 40)
                
                Text("Change After ^[\(Int(duration.rounded())) Second](inflect: true)")
                    .monospacedDigit()
                Slider(value: $duration, in: 5...60)
                    .padding(.bottom, 40)
                
                Toggle(isOn: $adjustSize) {
                    Label("Adjust Globe Size", systemImage: "circle.circle")
                }
                
                Spacer()
            }
            .navigationSplitViewColumnWidth(260)
            .padding()
            .navigationTitle("Play Sequence")
        } detail: {
            ScrollView(.vertical, showsIndicators: false) {
                let columns = [GridItem(.adaptive(minimum: 150))]
                LazyVGrid(columns: columns) {
                    ForEach(model.filteredGlobes(selection: selection)) { globe in
                        GlobeView(globe: globe)
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
    
    private func binding(for selection: GlobeSelection) -> Binding<Bool> {
        Binding (
            get: { selection == self.selection },
            set: { selected in
                if selected {
                    self.selection = selection
                }
            }
        )
    }
}

#if DEBUG
#Preview {
    PlayView()
        .environment(ViewModel.preview)
        .frame(width: 800)
        .glassBackgroundEffect()
}
#endif
