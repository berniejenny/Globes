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
        Globe(
            name: "Natural Earth I",
            authorSurname: "Patterson",
            authorFirstName: "Tom",
            date: "2005",
            description: "Natural Earth is a public domain map dataset available at 1:10m, 1:50m, and 1:110 million scales. Featuring tightly integrated vector and raster data, with Natural Earth you can make a variety of visually pleasing, well-crafted maps with cartography or GIS software.",
            infoURL: URL(string: "https://www.naturalearthdata.com"),
            radius: 0.4,
            texture: "NE1_50M_SR_W"
        )
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
