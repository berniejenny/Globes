//
//  ViewModel+Preview.swift
//  Globes
//
//  Created by Bernhard Jenny on 15/3/2024.
//

import SwiftUI

extension ViewModel {
    
    @MainActor
    static var preview: ViewModel {
        ViewModel.shared
    }
}
