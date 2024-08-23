//
//  ViewModel.swift
//  Globes
//
//  Created by Bernhard Jenny on 15/3/2024.
//

import os
import RealityKit
import SwiftUI
import SharePlayMock
import Combine
import GroupActivities

/// A singleton model that can be accessed via `ViewModel.shared`, for example, by the app delegate. For SwiftUI, use the new Observable framework instead of accessing the shared singleton.
///
/// The `Globe` struct is a static description of a globe containing all metadata and a texture name. A globe has an id (i.e. Globe.ID), which is used as keys for dictionaries to associate globes with a configuration and a 3D entity.
///
/// `globes` is an array of Globe structs that are loaded from Globes.json. This array does not change, except when custom globes are added (this is yet to be implemented).
///
/// `configurations` is a dictionary of `GlobeConfiguration` structs using `Globe.ID` keys. A configuration stores non-static properties of a globe, such as the rotation, the loading status, whether an attachment is visible, etc.  A configuration has a `globe` property, which changes for animated globes. A configuration also has `globeId` property of type `Globe.ID`, which is identical to the key of  the `configurations` dictionary. The `globeId` allows for looking up the `Globe` struct and `GlobeEntity` belonging to the configuration. `globeId` does not change, while `GlobeConfiguration.globe.id` changes when a globe texture is animated.
///
/// `globeEntities` is a dictionary of `GlobeEntity` classes using `Globe.ID` keys. After a globe is loaded, a `GlobeEntity` is initialized and added to this dictionary. SwiftUI observes this dictionary and synchronises the content of the `ImmersiveGlobeView` (a `RealityView`) with `globeEntities`. Identical to `GlobeConfiguration`, a `GlobeEntity` also has `globeId` property of type `Globe.ID`, which is identical to the key used by the `globeEntities` dictionary. The `globeId` allows for looking up the `Globe` struct and the `GlobeConfiguration` belonging to the entity.
///
///
/// For the new Observable framework: https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro
@Observable class ViewModel: CustomDebugStringConvertible {
    var openImmersiveSpaceAction: OpenImmersiveSpaceAction?
    
    /// Shared singleton that can be accessed by the AppDelegate.
    @MainActor
    static let shared = ViewModel()
    
    
    @MainActor
    /// The `Globe` struct is a static description of a globe containing all metadata and a texture name. A globe has an id (i.e. Globe.ID), which is used as keys for dictionaries to associate globes with a configuration and a 3D entity.
    var globes: [Globe] = []
    
    @MainActor
    
    /// An array of Globe structs of all available globes that are part of a selection.
    /// - Parameter selection: The selection
    /// - Returns: Filtered globes.
    func filteredGlobes(selection: GlobeSelection) -> [Globe] {
        switch selection {
        case .all:
            globes
        case .favorites:
            globes.filter { favorites.contains($0.id) }
        case .earth:
            globes.filter { $0.type == .earth }
        case .celestial:
            globes.filter { $0.type == .celestial }
        case .moon:
            globes.filter { $0.type == .moon }
        case .planets:
            globes.filter { $0.type == .planet || $0.type == .moonNonEarth }
        case .custom:
            globes.filter { $0.isCustomGlobe }
        case .none:
            []
        }
    }
    
    // MARK: - Visible Globes
    
    @MainActor
    /// `configurations` is a dictionary of `GlobeConfiguration` structs using `Globe.ID` keys. A configuration stores non-static properties of a globe, such as the rotation, the loading status, whether an attachment is visible, etc.  A configuration has a `globe` property, which changes for animated globes. A configuration also has `globeId` property of type `Globe.ID`, which is identical to the key of  the `configurations` dictionary. The `globeId` allows for looking up the `Globe` struct and `GlobeEntity` belonging to the configuration. `globeId` does not change, while `GlobeConfiguration.globe.id` changes when a globe texture is animated.
    var configurations: [Globe.ID: GlobeConfiguration] = [:]
    
    @MainActor
    func hasConfiguration(for globeId: Globe.ID) -> Bool {
        configurations.keys.contains(globeId)
    }
    
    @MainActor
    /// `globeEntities` is a dictionary of `GlobeEntity` classes using `Globe.ID` keys. After a globe is loaded, a `GlobeEntity` is initialized and added to this dictionary. SwiftUI observes this dictionary and synchronises the content of the `ImmersiveGlobeView` (a `RealityView`) with `globeEntities`. Identical to `GlobeConfiguration`, a `GlobeEntity` also has `globeId` property of type `Globe.ID`, which is identical to the key used by the `globeEntities` dictionary. The `globeId` allows for looking up the `Globe` struct and the `GlobeConfiguration` belonging to the entity.
    var globeEntities: [Globe.ID: GlobeEntity] = [:]
    
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
    /// Open an immersive space if there is none and show a globe. Once loaded, the globe fades in and is positioned such that it should not touch any existing globe.
    /// - Parameters:
    ///   - globe: The globe to show.
    ///   - selection: When selection is not `none`, the texture is replaced periodically with a texture of one of the globes in the selection.
    ///   - openImmersiveSpaceAction: Action for opening an immersive space.
    func load(
        globe: Globe,
        selection: GlobeSelection = .none,
        openImmersiveSpaceAction: OpenImmersiveSpaceAction
    ) {
        guard !hasConfiguration(for: globe.id) else { return }
        
        var configuration = GlobeConfiguration(
            selection: selection,
            globe: globe,
            speed: GlobeConfiguration.defaultRotationSpeed,
            isRotationPaused: !rotateGlobes
        )
        // Need to send the configuration over so the new user can initialise a globe with the same config
        // No need to send message here because the method that calls load() will send the message
        activityState.sharedGlobeConfiguration[globe.id] = configuration
        configuration.isLoading = true
        configuration.isVisible = false
        configuration.showAttachment = false
        
        configuration.isLoading = true
        configurations[globe.id] = configuration
        
        Task {
            openImmersiveGlobeSpace(openImmersiveSpaceAction)
            await SerialGlobeLoader.shared.load(globe: globe)
        }
    }
    
    @MainActor
    /// Called by `SerialGlobeLoader` when a new globe entity has been loaded.
    /// - Parameter globeEntity: The globe entity to add.
    func storeGlobeEntity(_ globeEntity: GlobeEntity) {
        let id = globeEntity.globeId
        
        // toggle the loading flag of the configuration
        guard var configuration = configurations[id] else {
            errorToShowInAlert = error("The globe cannot be shown.")
            Logger().error("The configuration cannot be found for a new globe entity.")
            return
        }
        configuration.isLoading = false
        configuration.isVisible = true
        configurations[id] = configuration
        
        // Set the initial scale and position for a move-in animation.
        // The animation is started by a DidAddEntity event when the immersive space has been created and the globe has been added to the scene.
        globeEntity.scale = [0.01, 0.01, 0.01]
        globeEntity.position = configuration.positionRelativeToCamera(distanceToGlobe: 2)
        
        // Rotate the central meridian to the camera, to avoid showing the empty hemisphere on the backside of some globes.
        // The central meridian is at [-1, 0, 0], because the texture u-coordinate with lat = -180° starts at the x-axis.
        if let viewDirection = CameraTracker.shared.viewDirection {
            var orientation = simd_quatf(from: [-1, 0, 0], to: -viewDirection)
            orientation = GlobeEntity.orientToNorth(orientation: globeEntity.orientation)
            globeEntity.orientation = orientation
        }
        
        // store the globe entity
        globeEntities[id] = globeEntity
        
        AppStore.increaseGlobesCount(promptReview: false)
    }
    
    @MainActor
    var uniformSizeForAnimatedGlobe: Bool {
        // scale and adjust the position before showing the new texture
        if UserDefaults.standard.object(forKey: "AnimationUniformSize") == nil {
            return true // default for boolean values is false if the value does not exist, but we want true
        } else {
            return UserDefaults.standard.bool(forKey: "AnimationUniformSize")
        }
    }
    
    @MainActor
    /// Called by `SerialGlobeLoader` when a new globe entity for an animated globe has been loaded.
    /// - Parameters:
    ///   - globeEntity: The loaded globe entity.
    ///   - entityID: The id of the animated globe entity.
    func storeAnimatedGlobe(_ globeEntity: GlobeEntity, entityID: UInt64) {
        let transformDuration = GlobeEntity.transformAnimationDuration / 2
        if let newGlobe = globes.first(where: { $0.id == globeEntity.globeId }),
           let animatedGlobeEntity = globeEntities.values.first(where: { $0.id == entityID }),
           var animatedConfiguration = configurations[animatedGlobeEntity.globeId] {
            
            let oldScale = animatedGlobeEntity.scale
            let newRadius = animatedConfiguration.globe.radius
            var newScale = newGlobe.radius / animatedConfiguration.globe.radius * oldScale.x
            newScale = min(newScale, GlobeConfiguration.maxDiameter / newRadius)
            newScale = max(newScale, GlobeConfiguration.minDiameter / newRadius)
            
            let uniformSize = uniformSizeForAnimatedGlobe
            if !uniformSize {
                animatedGlobeEntity.scaleAndAdjustDistanceToCamera(
                    newScale: newScale,
                    radius: newRadius,
                    duration: transformDuration)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + transformDuration) {
                guard let modelComponent = globeEntity.modelEntity?.components[ModelComponent.self] else { return }
                
                // update the model
                animatedGlobeEntity.modelEntity?.components.set(modelComponent)
                
                // update the collision shape
                let collisionSphere = ShapeResource.generateSphere(radius: newGlobe.radius)
                animatedGlobeEntity.components.set(CollisionComponent(shapes: [collisionSphere], mode: .trigger))
                
                // adjust the scale
                if uniformSize {
                    let newScale = newRadius / newGlobe.radius
                    animatedGlobeEntity.scale = [newScale, newScale, newScale] * oldScale
                } else {
                    animatedGlobeEntity.scale = oldScale
                }
                
                // store the loaded globe in the configuration for display of meta info
                animatedConfiguration.globe = newGlobe
                self.configurations[animatedGlobeEntity.globeId] = animatedConfiguration
            }
        }
    }
    
    @MainActor
    /// A new globe entity could not be loaded.
    /// - Parameters:
    ///   - id: The id of the globe that could not be loaded.
    func loadingGlobeFailed(id: Globe.ID?) {
        if let id {
            configurations.removeValue(forKey: id)
            globeEntities.removeValue(forKey: id)
        }
        errorToShowInAlert = error("There is not enough memory to show another globe.",
                                   secondaryMessage: "First hide a visible globe, then select this globe again.")
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
            assert(configurations.keys.contains(id), "No configuration for \(id)")
            assert(globeEntities.keys.contains(id), "No globe entity for \(id)")
            configurations[id] = nil
            globeEntities[id] = nil
        }
    }
    
    @MainActor
    /// Hide all currently visible globes and delete their GlobeConfiguration` and `GlobeEntity`.
    func hideAllGlobes() {
        for globeId in configurations.keys {
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
    private func canPlaceGlobe(at position: SIMD3<Float>, with radius: Float, spacing: Float = 0.05) -> Bool {
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
    
    @MainActor
    /// Returns a  position for a new globe. Tries to find a position that does not result in intersections with existing globes.
    /// - Parameters:
    ///   - configuration: Configuration of the new globe.
    /// - Returns: Position of the center of the globe.
    func targetPosition(for globeId: Globe.ID) -> SIMD3<Float> {
        guard let configuration = configurations[globeId] else {
            return [0, 1, -1]
        }
        
        let targetPosition = configuration.positionRelativeToCamera(distanceToGlobe: 0.5)
        if canPlaceGlobe(at: targetPosition, with: configuration.globe.radius) {
            return targetPosition
        }
        
        // search for a free position
        // local coordinate system with x-axis perpendicular to the viewing direction
        guard let cameraViewDirection = CameraTracker.shared.viewDirection else {
            return SIMD3(0, 1, 0)
        }
        let toCamera = cameraViewDirection * -1
        let rightAxis = SIMD3(toCamera.z, 0, -toCamera.x)
        let upAxis = cross(toCamera, rightAxis)
        
        // a few rotations in an Archimedean spiral
        let rotations = 10
        let spacing = configuration.globe.radius + 0.1
        let b = spacing / (2 * .pi)
        // stretch the spiral horizontally and compress it vertically to position globes in a landscape format
        let stretch: Float = 1.5
        for alphaDeg in stride(from: 3, to: rotations * 360, by: 3) {
            let omega = Float(alphaDeg) / 180 * .pi
            let r = b * omega
            let x = cos(omega) * r * stretch
            let y = sin(omega) * r / stretch
            let candidatePosition = targetPosition + x * rightAxis + y * upAxis
            if canPlaceGlobe(at: candidatePosition, with: configuration.globe.radius) {
                return candidatePosition
            }
        }
        
        // could not find an empty spot
        return targetPosition
    }
    
    // MARK: - Visible Panorama
    
    @MainActor
    var isShowingPanorama: Bool { panoramaGlobe != nil }
    
    @MainActor
    /// The globe that is currently shown as panorama.
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
    /// Open a panorama with the passed globe and open an immersive space if none is currently open.
    /// - Parameters:
    ///   - globe: The globe to show on the panorama.
    ///   - openImmersiveSpaceAction: Action to call to open the immersive space.
    func loadPanorama(globe: Globe, openImmersiveSpaceAction: OpenImmersiveSpaceAction) {
        let panoramaIsLoaded = panoramaGlobe?.id == globe.id
        guard !panoramaIsLoaded else { return }
        
        panoramaGlobeToLoad = globe
        
        Task {
            do {
                openImmersiveGlobeSpace(openImmersiveSpaceAction)
                await SerialGlobeLoader.shared.load(panorama: globe)
            }
        }
    }
    
    @MainActor
    /// Called by `SerialGlobeLoader` when a new panorama entity has been loaded.
    /// - Parameter panoramaEntity: The panorama entity to add.
    func storePanoramaEntity(_ panoramaEntity: PanoramaEntity) {
        panoramaGlobe = panoramaGlobeToLoad
        panoramaGlobeToLoad = nil
        self.panoramaEntity = panoramaEntity
        AppStore.increaseGlobesCount(promptReview: false)
    }
    
    @MainActor
    /// A new panorama entity could not be loaded.
    func loadingPanoramaFailed() {
        panoramaGlobeToLoad = nil
        errorToShowInAlert = error("There is not enough memory to show this panorama.",
                                   secondaryMessage: "First hide a globe \(isShowingPanorama ? "or the current panorama" : ""), then select the panorama again.")
    }
    
    @MainActor
    func hidePanorama() {
        panoramaGlobe = nil
        panoramaEntity = nil
    }
    
    @MainActor
    /// The globe that is currently loaded and later shown as a panorama.
    var panoramaGlobeToLoad: Globe? = nil
    
    @MainActor
    var isLoadingPanorama: Bool {
        panoramaGlobeToLoad != nil
    }
    
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
    
    @MainActor
    private func openImmersiveGlobeSpace(_ action: OpenImmersiveSpaceAction) {
        guard !immersiveSpaceIsShown else { return }
        Task {
            let result = await action(id: "ImmersiveGlobeSpace")
            switch result {
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
    
    // MARK: - Collisions
    
    /// Time of last detected collision
    var lastCollisionTime = -TimeInterval.infinity
    
    // MARK: - Debug Description
    
    @MainActor
    var debugDescription: String {
        var description = "\(ViewModel.self) with \(globes.count) globes\n"
        
        // Memory
        let availableProcMemory = os_proc_available_memory()
        description += "Available memory: \(availableProcMemory / 1024 / 1024) MB\n"
        
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
        description += "Rotate globes: \(rotateGlobes)\n"
        description += "Globe configurations: \(configurations.count), entities: \(globeEntities.count)\n"
        for (index, configuration) in configurations.values.enumerated() {
            let entity = globeEntities[configuration.globeId]
            description += "\t\(index + 1): \(configuration.globe.name)"
            description += entity == nil ? ", NOT loaded\n" : ", loaded"
            if let entity {
                description += ", pos=\(entity.position.x),\(entity.position.y),\(entity.position.z)"
                description += ", scale=\(entity.scale.x),\(entity.scale.y),\(entity.scale.z)"
            }
            description += "\n"
        }
        
        // panorama
        description += "Show panorama: \(isShowingPanorama)\n"
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
    
    // MARK: SharePlay Variables
    
    var activityState = ActivityState()
    var sharePlayEnabled = false
#if DEBUG
    var groupSession: GroupSessionMock<MyGroupActivity>?
    var messenger: GroupSessionMessengerMock?
#else
    var groupSession: GroupSession<MyGroupActivity>?
    var messenger: GroupSessionMessenger?
#endif
    
    
    var subscriptions: Set<AnyCancellable> = []
    var tasks: Set<Task<Void, Never>> = []
    
    
    
    
    
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
            
            self.configureGroupSessions()
            Registration.registerGroupActivity()
        }
    }
    
    
}
