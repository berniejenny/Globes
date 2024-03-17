//
//  Globe+Preview.swift
//  Globes
//
//  Created by Bernhard Jenny on 14/3/2024.
//

import Foundation

extension Globe {
    
    /// A globe for previewing SwiftUI views.
    static var preview: Globe {
        guard let globe = previewGlobes.first else {
            fatalError("Globes.json does not contain any valid globe.")
        }
        return globe
    }

    /// Globes loaded from Globes.json
    static var previewGlobes: [Globe] {
        do {
            let url = Bundle.main.url(forResource: "Globes", withExtension: "json")!
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Globe].self, from: data)
        } catch {
            fatalError("An error occurred when loading Globes.json from the bundle: \(error.localizedDescription)")
        }
    }
}
