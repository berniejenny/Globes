//
//  FavoritesView.swift
//  Globes
//
//  Created by Bernhard Jenny on 3/5/2024.
//

import SwiftUI

struct FavoritesView: View {
    @Environment(ViewModel.self) var model
    
    @MainActor
    private var favoriteGlobes: [Globe] {
        model.globes.filter { model.favorites.contains($0.id) }
    }
    
    var body: some View {
        if favoriteGlobes.isEmpty {
            ContentUnavailableView(
                "You have no favorite globes.",
                systemImage: "heart"
            )
        } else {
            GlobesGridView(globes: favoriteGlobes)
                .animation(.default, value: favoriteGlobes)
        }
    }
}

#Preview {
    FavoritesView()
}
