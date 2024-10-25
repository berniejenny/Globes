//
//  SharePlay.swift
//  VisionSharePlayTest
//
//  Created by BooSung Jung on 30/7/2024.
//
import SwiftUI
import GroupActivities
import SharePlayMock
import Combine
import os

extension ViewModel {
    
    /// This function loops through active sessions and manages tasks
    func configureGroupSessions(){
        Task(priority: .high) {
            for await groupSession in MyGroupActivity.sessions() {
                
                // set group session messenger
                self.groupSession = groupSession
#if DEBUG
                let messenger = GroupSessionMessengerMock(session: groupSession)
#else
                let messenger = GroupSessionMessenger(session: groupSession)
#endif
                // set the messenger
                self.messenger = messenger
                
                
                groupSession.$state.sink {
                    // this Tearsdown existing group session
                    if case .invalidated = $0 {
                        self.cleanupGroupSession()
                    }
                }
                .store(in: &self.subscriptions)
                // store the subscription in the subscriptions set
                
                // sink observes and reacts to changes in the group session activeParticipants
                groupSession.$activeParticipants
                    .sink {
                        
                        let newParticipants = $0.subtracting(groupSession.activeParticipants)
                        Task {
                            // if there is a new participant send the activity state to only the new participants
                            // https://developer.apple.com/videos/play/wwdc2021/10187/
                            // 19:33
                            try? await messenger.send(self.activityState,
                                                      to: .only(newParticipants))
                        }
                    }
                    .store(in: &self.subscriptions)
                
                
                // listen to messages from the group session
                self.tasks.insert(
                    Task {
                        for await (message, context) in messenger.messages(of: ActivityState.self) {
                            if context.source != groupSession.localParticipant {
                                await self.receive(message)
                            }
                        }
                    }
                )
                self.tasks.insert(
                    Task {
                        @MainActor in
                        sharePlayEnabled = true
                    }
                )
                
                
                // this section of code assigns the systemCoordinator to the groupSession
                self.tasks.insert(
                    Task {
                        if let systemCoordinator = await groupSession.systemCoordinator {
                            var configuration = SystemCoordinator.Configuration()
                            
                            //enable support
                            configuration.supportsGroupImmersiveSpace = true
                            
                            // https://developer.apple.com/videos/play/wwdc2023/10087/?time=248
                            // we are using .surround since we are viewing a globe
                            if #available(visionOS 2.0, *) {
                                configuration.spatialTemplatePreference = .surround.contentExtent(200)
                            } else {
                                // Fallback on earlier versions
                            }
                            systemCoordinator.configuration = configuration
                            groupSession.join()
                        }
                    }
                )
            }
        }
    }
    
    
    // MARK: Manual toggle for shareplay
    @MainActor
    func toggleSharePlay() {
        if (!self.sharePlayEnabled) {
            startSharePlay()
        } else {
            endSharePlay()
        }
    }
    
    /// Start the sharePlay Manually if this function is triggered
    @MainActor
    func startSharePlay() {
        Task {
            let activity = MyGroupActivity()
            switch await activity.prepareForActivation() {
            case .activationPreferred:
                do {
                    _ = try await activity.activate()
                    // Send a message indicating this participant started the session
                    if self.messenger != nil {
                        self.activityState.owner = UIDevice.current.identifierForVendor?.uuidString
                    }
                } catch {
                    Logger().info("SharePlay unable to activate the activity")
                }
            case .activationDisabled:
                Logger().info("SharePlay group activity activation disabled")
            case .cancelled:
                Logger().info("SharePlay group activity activation cancelled")
            @unknown default:
                Logger().info("SharePlay group activity activation unknown case")
                print("SharePlay group activity activation unknown case")
            }
        }
    }
    
    /// Stop the shareplay session
    func endSharePlay() {
        self.groupSession?.end()
    }
    
    @MainActor
    func sendMessage(isAcknowledgment: Bool = false) {
        guard sharePlayEnabled else { return }

        DispatchQueue.main.async {
            if self.activityState.owner == nil {
                self.forceClaimOwnership()
            }

            // Send only if the user is the owner or the message is an acknowledgment
            if isAcknowledgment || self.isOwner {
                self.subject.send(self.activityState)
            }
        }
    }

    func receive(_ message: ActivityState) {
        
        // We do not want to receive messages if sharePlay is not active
        guard sharePlayEnabled else { return }
        
        Task{ @MainActor in
            
            
            
            // update the activity state with the new message passed from other users
            self.activityState = message
            // after we get the new activity state we need to update the UI/Globe position
            
            self.updateEntity()
        }
    }
    
    
    @MainActor
    func sendAcknowledgment() {
        // Mark the current device as acknowledged
        self.activityState.participantsAcknowledgments[UIDevice.current.identifierForVendor!.uuidString] = true
        self.sendMessage(isAcknowledgment: true) // Send the acknowledgment message
    }
    
    
    @MainActor
    func relinquishOwnershipIfNeeded() {
        // Check if all participants have acknowledged the changes
        let allAcknowledged = self.activityState.participantsAcknowledgments.allSatisfy { $0.value == true }
        
        // Check if all transformations are complete
        let allTransformationsComplete = self.activityState.globeTransformations.allSatisfy { $0.value.globeChange == GlobeChange.none }
        
        // Check if any globe is still animating
        let allAnimationsComplete = self.globeEntities.allSatisfy { $0.value.isAnimating == false }
        
        // Only relinquish ownership if all acknowledgments, transformations, and animations are complete
        if allAcknowledged && allTransformationsComplete && allAnimationsComplete {
            // Reset ownership and acknowledgments
            self.activityState.owner = nil
            self.activityState.participantsAcknowledgments.removeAll()
            
            // Notify others that ownership has been relinquished
            self.sendMessage()
        }
    }
    
    
    
    
    
    @MainActor
    func forceClaimOwnership() {
        if self.isOwner{
            return
        }
        Task(priority: .high) {
            // Ensure ownership update happens on the main thread and synchronously
            await MainActor.run {
                self.activityState.owner = UIDevice.current.identifierForVendor?.uuidString
                self.sendMessage()
            }


            // Check if ownership state was retained or reverted
            if self.activityState.owner != UIDevice.current.identifierForVendor?.uuidString {
                // Log or handle the ownership conflict if necessary
                Logger().info("Ownership force claim failed, reverting to previous owner")
            }
        }
    }
    
    
    
    
    /// This funtion is called every time the user receives a message and updates all the globe entities according to their activityState.changes
    /// even if user A sends the message, user A will receive the same message, therefore we need to do checks so we don't duplicate the same actions
    @MainActor
    private func updateEntity() {
        Task{
            guard let openImmersiveSpaceAction else{
                return
            }
            if self.isOwner{
                return
            }
            // Iterate through all the activityState changes
            for (globeID, change) in activityState.globeTransformations {
                guard let globeConfiguration = activityState.sharedGlobeConfigurations[globeID] else{
                    return
                }
                updateEntityChanges(globeID: globeID, change: change)
                
                // if the activityState contains a globe and the local user does not. We want to follow the activityState by loading the globe for the current user. Additionally, if the activityState does not contain the globe we want to hide it.
                if !self.hasConfiguration(for: globeID){
                    load(globe: globeConfiguration.globe, openImmersiveSpaceAction: openImmersiveSpaceAction)
                    self.configurations[globeID]?.isRotationPaused = globeConfiguration.isRotationPaused
                }
            }
            
            for (globeID, globeEntity) in self.globeEntities{
                if !self.activityState.globeTransformations.keys.contains(globeID) && !globeEntity.isAnimating{
                    self.hideGlobe(with: globeID)
                }
            }
            
        }
    }
    
    @MainActor
    func updateEntityChanges(globeID: Globe.ID, change: TempTransform){
        // Check if globe configuration in the activity state exists
        guard let globeConfiguration = activityState.sharedGlobeConfigurations[globeID] else{
            return
        }
        
        guard let openImmersiveSpaceAction else{
            return
        }
        
        // We will go through each type of changes and compute what is necessary. Once done we will reset
        // the globeChange to none
        switch change.globeChange {
        case .load: // We need to load the globe
            // Rather than checking if configurations[globeID] we need to check the sharedGlobeConfiguration because the local configuration will not exist if the globe has not been loaded
            if !globeConfiguration.isVisible{ // check if globe is not visible
                load(globe: globeConfiguration.globe, openImmersiveSpaceAction: openImmersiveSpaceAction)
                // The globe rotation setting may be different for each user so we will set the default rotation bool to whomever sends the message first
                self.configurations[globeID]?.isRotationPaused = globeConfiguration.isRotationPaused
                self.activityState.globeTransformations[globeID]?.globeChange = GlobeChange.none
            }
        case .hide: // We need to hide the globe
            // we need to check if there is a local configuration. If not, it means the globe does not exist hence already hidden.
            self.activityState.globeTransformations.removeValue(forKey: globeID)
            self.activityState.sharedGlobeConfigurations.removeValue(forKey: globeID)
            self.sendMessage(isAcknowledgment: true)
            hideGlobe(with: globeID)
        case .transform: // We need to transform the globe to a new position
            if let tempTranslation = self.activityState.globeTransformations[globeID]{
                globeEntities[globeID]?.animateTransform(scale: tempTranslation.scale ?? 1,
                                                         orientation: tempTranslation.orientation ?? simd_quatf(angle: 0, axis: .init(x: 0, y: 0, z: 1)),
                                                         position: tempTranslation.position ?? .zero,
                                                         duration: tempTranslation.duration ?? 0.2)
                
                self.activityState.globeTransformations[globeID]?.globeChange = GlobeChange.none
            }
        case .update:
            // Update necessary globe configurations
            self.configurations[globeID]?.isRotationPaused = globeConfiguration.isRotationPaused
            self.activityState.globeTransformations[globeID]?.globeChange = GlobeChange.none
        case nil:
            break
        case .some(.none):
            break
        }
    }
    
    /// function will reset the group session
    private func cleanupGroupSession() {
        sharePlayEnabled = false
        self.messenger = nil
        self.tasks.forEach { $0.cancel() }
        self.tasks = []
        self.subscriptions = []
        self.groupSession = nil
        self.activityState = ActivityState()
    }
    
    /// Enum to indicate the errors
    private enum ActivationError: Error {
        case failed, disabled, cancelled, unknown
    }
}
