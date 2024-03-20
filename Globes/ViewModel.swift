//
//  ViewModel.swift
//  Globes
//
//  Created by Bernhard Jenny on 15/3/2024.
//

import SwiftUI

@Observable class ViewModel {    
    /// The configuration of the currently selected globe. Nil if no globe is selected.
    var selectedGlobeConfiguration: GlobeEntity.Configuration? = nil
}
