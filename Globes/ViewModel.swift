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
    
    /// Hide small preview globes when an alert, a confirmation dialog or a sheet is shown to avoid intersections between these views and the globes
    var hidePreviewGlobes = false
    
    /// If non-nil the main window is displaying this web page.
    var webURL: URL? = nil
}
