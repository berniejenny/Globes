//
//  GalleryView.swift
//  Globes
//
//  Created by Bernhard Jenny on 2/5/2024.
//

import SwiftUI

struct GalleryView: View {
    @Environment(ViewModel.self) var model
    
    @State private var globeSelection = GlobeSelection.all
   
    private let selections: [GlobeSelection] = [.all, .earth, .celestial, .moon, .planets]
    
    var body: some View {
        GlobesGridView(globes: model.filteredGlobes(selection: globeSelection))
            .animation(.default, value: globeSelection)
            .ornament(attachmentAnchor: .scene(.top), contentAlignment: .bottom) {
                HStack {
                    ForEach(selections) { selection in
                        Toggle(isOn: binding(for: selection)) {
                            Label(selection.rawValue.localizedCapitalized, systemImage: selection.systemImage)
                        }
                        .toggleStyle(.button)
                        .help(selection.help)
                        .disabled(selection == .custom && !hasCustomGlobes)
                    }
                }
                .padding()
                .glassBackgroundEffect()
                .padding()
            }
            .onChange(of: model.globes.count) {
                Task { @MainActor in
                    try await Task.sleep(for: .seconds(0.2))
                    if globeSelection == .custom && !hasCustomGlobes {
                        globeSelection = .all
                    }
                }
            }
    }
    
    @MainActor
    private var hasCustomGlobes: Bool {
        !model.globes.filter { $0.isCustomGlobe }.isEmpty
    }
    
    private func binding(for selection: GlobeSelection) -> Binding<Bool> {
        Binding (
            get: { selection == globeSelection },
            set: { selected in
                if selected {
                    globeSelection = selection
                }
            }
        )
    }
}

#if DEBUG
#Preview {
    GalleryView()
        .environment(ViewModel.preview)
        .glassBackgroundEffect()
}
#endif
