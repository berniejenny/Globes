//
//  ViewModel+Preview.swift
//  Globes
//
//  Created by Bernhard Jenny on 15/3/2024.
//

import SwiftUI

extension ViewModel {
    static var preview: ViewModel { ViewModel() }
    
    static var previewWithSelectedGlobe: ViewModel {
        let viewModel = ViewModel()
        Task { @MainActor in
            viewModel.selectedGlobeConfiguration = .init(globe: Globe.preview)
        }
        return viewModel
    }
}
