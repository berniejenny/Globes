//
//  GalleryView.swift
//  Globes
//
//  Created by Bernhard Jenny on 2/5/2024.
//

import SwiftUI

struct GalleryView: View {
    @Environment(ViewModel.self) var model
    
    private enum Category: String, Hashable, CaseIterable {
        case all, earth, celestial, moon, planets//, custom
        
        var systemImage: String {
            switch self {
            case .all:
                "globe"
            case .earth:
                "globe.europe.africa.fill"
            case .celestial:
                "sparkles"
            case .moon:
                "moon.fill"
            case .planets:
                "circle"
//#warning("Custom globes")
//            case .custom:
//                "hammer.fill"
            }
        }
        
        var help: String {
            switch self {
            case .all:
                "All Globes"
            case .earth:
                "Terrestrial Globes"
            case .celestial:
                "Star Constellations in The Sky"
            case .moon:
                "Earth’s Moon"
            case .planets:
                "Planets and Their Moons"
//#warning("Custom globes")
//            case .custom:
//                "Custom Globes"
            }
        }
    }
    
    @State private var selectedCategory = Category.all
    
    @MainActor
    private var globes: [Globe] {
        switch selectedCategory {
        case .all:
            model.globes
        case .earth:
            model.globes.filter { $0.type == .earth }
        case .celestial:
            model.globes.filter { $0.type == .celestial }
        case .moon:
            model.globes.filter { $0.type == .moon }
        case .planets:
            model.globes.filter { $0.type == .planet || $0.type == .moonNonEarth }
//#warning("Custom globes")
//        case .custom:
//            model.globes.filter { $0.textureURL != nil }
        }
    }
    
    var body: some View {
        GlobesGridView(globes: globes)
            .animation(.default, value: selectedCategory)
            .ornament(attachmentAnchor: .scene(.top), contentAlignment: .bottom) {
                HStack {
                    ForEach(Category.allCases, id: \.self) { category in
                        Toggle(isOn: binding(for: category)) {
                            Label(category.rawValue.localizedCapitalized, systemImage: category.systemImage)
                        }
                        .toggleStyle(.button)
                        .help(category.help)
#warning("Custom globes")
//                        .disabled(category == .custom && !hasCustomGlobes)
                    }
                }
                .padding()
                .glassBackgroundEffect()
                .padding()
            }
            .onChange(of: globes.count) {
                Task { @MainActor in
                    try await Task.sleep(for: .seconds(0.2))
#warning("Custom globes")
//                    if selectedCategory == .custom && !hasCustomGlobes {
//                        selectedCategory = .all
//                    }
                }
            }
    }
    
    @MainActor
    private var hasCustomGlobes: Bool {
        !model.globes.filter { $0.textureURL != nil }.isEmpty
    }
    
    private func binding(for category: Category) -> Binding<Bool> {
        Binding (
            get: { category == selectedCategory },
            set: { selected in
                if selected {
                    selectedCategory = category
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
