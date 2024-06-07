//
//  FavoriteGlobeButton.swift
//  Globes
//
//  Created by Bernhard Jenny on 5/5/2024.
//

import SwiftUI

struct FavoriteGlobeButton: View {
    @Environment(ViewModel.self) private var model
    
    let globeId: Globe.ID
    
    var body: some View {
        Toggle(isOn: favoriteBinding) {
            ButtonImage(name: favoriteBinding.wrappedValue ? "heart.fill" : "heart")
        }
        .buttonStyle(.plain)
        .toggleStyle(.button)
    }
    
    @MainActor
    private var favoriteBinding: Binding<Bool> {
        Binding(get: {
            model.favorites.contains(globeId)
        }, set: { favorite in
            model.favorite(favorite, globeId: globeId)
        })
    }
}

#if DEBUG
#Preview {
    FavoriteGlobeButton(globeId: Globe.preview.id)
        .padding()
        .glassBackgroundEffect()
        .environment(ViewModel.preview)
        .padding(50)
        .glassBackgroundEffect()
}
#endif
