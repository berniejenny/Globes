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
                            let sender = context.source
                            if sender == groupSession.localParticipant {
                                // Message from the local participant, we skip
                                continue
                            }
                            self.receive(message)
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
    
    /// Function to send the message to each participant
    func sendMessage() {
        
        // we don't want to share messages if sharePlay is not enabled
        if !sharePlayEnabled{
            return
        }
        // We are sending it after a delay to minimise cpu overload
        // self.subject.send will call the method inside of ViewModel.swift init method
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.subject.send(self.activityState)
        }
        
    }
    
  
    
    func receive(_ message: ActivityState) {
        
        // We do not want to receive messages if sharePlay is not active
        if !sharePlayEnabled{
            return
        }
        
        Task{ @MainActor in
            // update the activity state with the new message passed from other users
            self.activityState = message
            // after we get the new activity state we need to update the UI/Globe position
            self.updateEntity()
        }
    }
    
    /// This funtion is called every time the user receives a message and updates all the globe entities according to their activityState.changes
    /// even if user A sends the message, user A will receive the same message, therefore we need to do checks so we don't duplicate the same actions
    @MainActor
    private func updateEntity() {
        Task{
            
            // we need to check if the immersive space is active. Else we cannont do anything to globes that don't exist
            guard let openImmersiveSpaceAction = self.openImmersiveSpaceAction else{
                return
            }
            
            // Iterate through all the activityState changes
            for (globeID, change) in activityState.changes {
                
                // Check if globe configuration in the activity state exists
                guard let globeConfiguration = activityState.sharedGlobeConfiguration[globeID] else{
                    return
                }
                
                // We will go through each type of changes and compute what is necessary. Once done we will reset
                // the globeChange to none
                switch change.globeChange {
                    case .load: // We need to load the globe
                        if !globeConfiguration.isVisible{ // check if globe is not visible
                            load(globe: globeConfiguration.globe, openImmersiveSpaceAction: openImmersiveSpaceAction)
                            
                            activityState.changes[globeID]?.globeChange = GlobeChange.none
                        }
                    case .hide: // We need to hide the globe
                    // we need to check if there is a local configuration. If not, it means the globe does not exist hence already hidden.
                        guard let localGlobeConfiguration = configurations[globeID] else{
                            activityState.changes[globeID]?.globeChange = GlobeChange.none
                            return
                        }
                         if localGlobeConfiguration.isVisible {
                            activityState.sharedGlobeConfiguration.removeValue(forKey: globeID)
                            hideGlobe(with: globeID)
                            activityState.changes[globeID]?.globeChange = GlobeChange.none
                        }
                    case .transform: // We need to transform the globe
                        // Check if changes exist
                    
                    #warning("check if globeEntities.transformation is the same as tempTranslation if not, animate")
                        if let tempTranslation = self.activityState.changes[globeID]{
                            let scale = tempTranslation.scale!
                            let orientation = tempTranslation.orientation!
                            let position = tempTranslation.position ?? .zero
                            let duration = tempTranslation.duration ?? 0.2
                            
                            globeEntities[globeID]?.animateTransform(scale: scale, orientation: orientation, position: position, duration: duration)
                            activityState.changes[globeID]?.globeChange = GlobeChange.none
                        }
                    case .update:
                    // Update necessary globe configurations
                    self.configurations[globeID]?.isRotationPaused = globeConfiguration.isRotationPaused
                        activityState.changes[globeID]?.globeChange = GlobeChange.none
                    case nil: // Update the globe configuration
                        break
                    case .some(.none):
                        break
                }
            }
        
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
