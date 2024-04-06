//
//  ViewModel.swift
//  Globes
//
//  Created by Bernhard Jenny on 15/3/2024.
//

import os
import SwiftUI

@Observable class ViewModel {
    
    /// The configuration of the currently selected globe. Nil if no globe is selected.
    @MainActor
    var selectedGlobeConfiguration: GlobeConfiguration? = nil
    
    /// Set `selectedGlobeConfiguration` to nil.
    @MainActor
    func deselectGlobe() { selectedGlobeConfiguration = nil }
    
    /// True while the about dialog is shown.
    @MainActor
    var showingAboutSheet = false
    
    /// Hide small preview globes when an alert, a confirmation dialog or a sheet is shown to avoid intersections between these views and the globes.
    @MainActor
    var hidePreviewGlobes: Bool { showingAboutSheet || errorToShowInAlert != nil }
    
    /// If non-nil the main window is displaying this web page.
    @MainActor
    var webURL: URL? = nil
    
    /// Error to show in an alert dialog.
    @MainActor
    var errorToShowInAlert: Error? = nil {
        didSet {
            if let errorToShowInAlert {
                let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Globes Error")
                logger.error("Alert: \(errorToShowInAlert.localizedDescription) \(errorToShowInAlert.alertSecondaryMessage ?? "")")
            }
        }
    }
}
