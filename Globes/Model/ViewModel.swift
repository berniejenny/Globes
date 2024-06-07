//
//  ViewModel.swift
//  Globes
//
//  Created by Bernhard Jenny on 15/3/2024.
//

import os
import SwiftUI

@Observable class ViewModel: CustomDebugStringConvertible {
    @MainActor
    var globes: [Globe] = []
    
    // MARK: - Visible Globes
    
    /// The app is terminated by the operating system when more than 7 or 8 globes (plus a panorama) are loaded, even though Metal is only using a little more than 30% of the available GPU memory.
#warning("To be fixed: allow for more than 8 globes")
    private let maxNumberOfGlobes = 8
    
    @MainActor
    var configurations: [Globe.ID: GlobeConfiguration] = [:]
    
    @MainActor
    var globeEntities: [Globe.ID: GlobeEntity] = [:]
    
    @MainActor
    var canShowAnotherGlobe: Bool { configurations.count <= 7 }
    
    @MainActor
    /// Delete a custom globe.
    /// - Parameter id: Globe ID
    func deleteGlobe(with id: Globe.ID) {
        globeEntities[id]?.animateTransform(scale: 0.01,
                                            duration: GlobeEntity.transformAnimationDuration)
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(GlobeEntity.transformAnimationDuration))
            globes.removeAll(where: { $0.id == id })
            configurations.removeValue(forKey: id)
            globeEntities.removeValue(forKey: id)
            
            if panoramaGlobe?.id == id {
                panoramaGlobe = nil
                panoramaEntity = nil
            }
        }
    }
    
    @MainActor
    /// Open an immersive space if there is none and show a globe. The globe fades in and is positioned such that it should not touch any existing globe.
    /// - Parameters:
    ///   - globe: The globe to show.
    ///   - openImmersiveSpaceAction: Action for opening an immersive space.
    /// - Returns: True if successful.
    func show(globe: Globe, openImmersiveSpaceAction: OpenImmersiveSpaceAction) async -> Bool {
        if canShowAnotherGlobe {
            await openImmersiveGlobeSpace(openImmersiveSpaceAction)
            ResourceLoader.loadGlobe(globe: globe, model: self)
            return true
        } else {
            errorToShowInAlert = error("The maximum number of globes is shown.", secondaryMessage: "First hide another globe, then open this globe again.")
            return false
        }
    }
    
    @MainActor
    /// Hide a globe. The globe shrinks down. The corresponding `GlobeConfiguration` and `GlobeEntity` are deleted.
    /// - Parameter id: Globe ID
    func hideGlobe(with id: Globe.ID) {
        let duration = 0.666
        
        // shrink the globe
        if let globeEntity = globeEntities[id],
           let radius = globes.first(where: { $0.id == id })?.radius {
            globeEntity.scaleAndAdjustDistanceToCamera(
                newScale: 0.001, // scaling to 0 spins the globe, so scale to a value slightly greater than 0
                radius: radius,
                duration: duration
            )
        }
        
        // remove the globe from this model
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            configurations[id] = nil
            globeEntities[id] = nil
        }
    }
    
    @MainActor
    /// Hide all currently visible globes and delete their GlobeConfiguration` and `GlobeEntity`.
    func hideAllGlobes() {
        for globeId in globeEntities.keys {
            hideGlobe(with: globeId)
        }
    }
    
    @MainActor
    /// Rotation flag for large globes. Stored in user defaults.
    var rotateGlobes: Bool {
        get {
            access(keyPath: \.rotateGlobes) // https://developer.apple.com/wwdc23/10149?time=454
            if UserDefaults.standard.object(forKey: "RotateGlobes") == nil {
                return true // default for boolean values is false if the value does not exist, but we want true
            } else {
                return UserDefaults.standard.bool(forKey: "RotateGlobes")
            }
        }
        set {
            withMutation(keyPath: \.rotateGlobes) {
                UserDefaults.standard.set(newValue, forKey: "RotateGlobes")
            }
            
            configurations.keys.forEach {
                if var configuration = configurations[$0] {
                    configuration.isRotationPaused = !newValue
                    configurations[$0] = configuration
                }
            }
        }
    }
    
    @MainActor
    /// Tests whether a globe can be placed at a passed position without intersecting any other existing globe.
    /// - Parameters:
    ///   - position: Position to test.
    ///   - radius: Radius of the globe.
    ///   - spacing: Spacing between globes in meter.
    /// - Returns: True if a globe with `radius` can be positioned at `position`; false otherwise.
    func canPlaceGlobe(at position: SIMD3<Float>, with radius: Float, spacing: Float = 0.05) -> Bool {
        for (globeID, globeEntity) in globeEntities {
            let otherPosition = globeEntity.position(relativeTo: nil)
            guard let otherRadius = globes.first(where: { $0.id == globeID })?.radius else {
                return false
            }
            let otherScaledRadius = otherRadius * globeEntity.meanScale
            let distance = distance(position, otherPosition)
            if distance - otherScaledRadius < radius + spacing {
                return false
            }
        }
        return true
    }
    
    // MARK: - Visible Panorama
    
    @MainActor
    var showPanorama: Bool { panoramaGlobe != nil }
    
    @MainActor
    var panoramaGlobe: Globe? = nil
    
    @MainActor
    var panoramaEntity: PanoramaEntity? = nil
    
    @MainActor
    /// Immersion style for the panorama. Stored in user defaults.
    var panoramaImmersionStyle: PanoramaImmersionStyle {
        get {
            access(keyPath: \.panoramaImmersionStyle) // https://developer.apple.com/wwdc23/10149?time=454
            let rawValue = UserDefaults.standard.string(forKey: "PanoramaImmersionStyle") ?? PanoramaImmersionStyle.progressive.rawValue
            return PanoramaImmersionStyle(rawValue: rawValue) ?? .progressive
        }
        set {
            withMutation(keyPath: \.panoramaImmersionStyle) {
                UserDefaults.standard.set(newValue.rawValue, forKey: "PanoramaImmersionStyle")
            }
        }
    }
    
    @MainActor
    func hidePanorama() {
        panoramaGlobe = nil
        panoramaEntity = nil
    }
    
    @MainActor
    var isLoadingPanorama = false
    
    // MARK: - Lighting
    
    @MainActor
    /// Type of lighting for globes. Stored in user defaults.
    var lighting: Lighting {
        get {
            access(keyPath: \.lighting) // https://developer.apple.com/wwdc23/10149?time=454
            let rawValue = UserDefaults.standard.string(forKey: "Lighting") ?? Lighting.natural.rawValue
            return Lighting(rawValue: rawValue) ?? .natural
        }
        set {
            withMutation(keyPath: \.lighting) {
                UserDefaults.standard.set(newValue.rawValue, forKey: "Lighting")
            }
        }
    }
   
    let imageBasedLightIntensity: Float = 0
    
    // MARK: - Immersive Space
    
    @MainActor
    var immersiveSpaceIsShown = false
    
    func openImmersiveGlobeSpace(_ action: OpenImmersiveSpaceAction) async {
        guard await !immersiveSpaceIsShown else { return }
        switch await action(id: "ImmersiveGlobeSpace") {
        case .opened:
            Task { @MainActor in
                immersiveSpaceIsShown = true
            }
        case .error:
            Task { @MainActor in
                errorToShowInAlert = error("A globe could not be shown.")
            }
            fallthrough
        case .userCancelled:
            fallthrough
        @unknown default:
            Task { @MainActor in
                immersiveSpaceIsShown = false
            }
        }
    }
    
    // MARK: - Favorites
    
    @MainActor
    private(set) var favorites: Set<Globe.ID> = []
    
    @MainActor
    func favorite(_ favorite: Bool, globeId: Globe.ID) {
        if favorite {
            favorites.insert(globeId)
        } else {
            favorites.remove(globeId)
        }
        
        // write favorite globes to user defaults
        let favoriteIdStrings = favorites.map { $0.uuidString }
        UserDefaults.standard.set(favoriteIdStrings, forKey: "Favorites")
    }
    
    // MARK: - UI State
    
    @MainActor
    /// True if the user has not so far tapped a globe to see a globe attachment view. Stored in user defaults.
    var showOnboarding: Bool {
        get {
            access(keyPath: \.showOnboarding) // https://developer.apple.com/wwdc23/10149?time=454
            if UserDefaults.standard.object(forKey: "ShowOnboarding") == nil {
                return true // default for boolean values is false if the value does not exist, but we want true
            } else {
                return UserDefaults.standard.bool(forKey: "ShowOnboarding")
            }
        }
        set {
            withMutation(keyPath: \.showOnboarding) {
                UserDefaults.standard.set(newValue, forKey: "ShowOnboarding")
            }
        }
    }

    @MainActor
    /// Hide small preview globes when an alert, a confirmation dialog or a sheet is shown to avoid intersections between these views and the globes.
    var hidePreviewGlobes: Bool { errorToShowInAlert != nil }
       
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
    
    @MainActor
    /// If non-nil, show the gallery view and scroll its list such that this globe is visible.
    var scrollGalleryToGlobe: Globe.ID? = nil
    
    // MARK: - Debug Description
    
    @MainActor
    var debugDescription: String {
        var description = "\(ViewModel.self) with \(globes.count) globes\n"
        
        // Metal memory
        if let defaultDevice = MTLCreateSystemDefaultDevice () {
            let workingSet = defaultDevice.recommendedMaxWorkingSetSize
            if workingSet > 0 {
                let currentUse = defaultDevice.currentAllocatedSize
                description += "Allocated GPU memory: \(100 * UInt64(currentUse) / workingSet)%, \(currentUse / 1024 / 1024) MB of \(workingSet / 1024 / 1024) MB\n"
            }
        }
        
        description += "Immersive space is shown: \(immersiveSpaceIsShown)\n"
        
        // globes
        description += "Can show another globe: \(canShowAnotherGlobe)\n"
        description += "Rotate globes: \(rotateGlobes)\n"
        description += "Globe configurations: \(configurations.count), entities: \(globeEntities.count)\n"
        for (index, configurationKeyValue) in configurations.enumerated() {
            let globeId = configurationKeyValue.key
            guard let globe = globes.first(where: { $0.id == globeId }) else {
                description += "*** Cannot find globe for \(globeId)"
                continue
            }
            let entity = globeEntities[globeId]
            description += "\t\(index + 1): \(globe.name)"
            description += entity == nil ? ", NOT loaded\n" : ", loaded"
            if let entity {
                description += ", pos=\(entity.position.x),\(entity.position.y),\(entity.position.z)"
                description += ", scale=\(entity.scale.x),\(entity.scale.y),\(entity.scale.z)"
//                description += ", orientation=\(entity.orientation)"
                print(entity)
            }
            description += "\n"
        }
        
        // panorama
        description += "Show panorama: \(showPanorama)\n"
        if let panoramaGlobe {
            description += "\tPanorama: \(panoramaGlobe.name)"
            description += panoramaEntity == nil ? ", NOT loaded\n" : ", loaded\n"
        }
        
        // lighting
        description += "Lighting: \(lighting)\n"
        
        // error handling
        if let errorToShowInAlert {
            description += "Error to show: \(errorToShowInAlert.localizedDescription)\n"
        }
        
        if let scrollGalleryToGlobe,
           let globe = globes.first(where: { $0.id == scrollGalleryToGlobe }) {
            description += "Custom globe to select: \(globe.name)\n"
        }
        
        
        return description
    }
    
    // MARK: - Initializer
    
    init() {
        Task { @MainActor in
            // load Globes.json
            do {
                let url = Bundle.main.url(forResource: "Globes", withExtension: "json")!
                let data = try Data(contentsOf: url)
                globes = try JSONDecoder().decode([Globe].self, from: data)
            } catch {
                fatalError("An error occurred when loading Globes.json from the bundle: \(error.localizedDescription)")
            }
            
            // load favorite globes from user defaults
            let favoriteIdStrings = UserDefaults.standard.object(forKey: "Favorites") as? [String] ?? []
            favorites = Set(favoriteIdStrings.compactMap { UUID(uuidString: $0) })
        }
    }
}
