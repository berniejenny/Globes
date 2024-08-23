//
//  SharePlay.swift
//  VisionSharePlayTest
//
//  Created by BooSung Jung on 30/7/2024.
//
import SwiftUI
import GroupActivities
import SharePlayMock


/// User can break out of the spatial persona and if they want to return to the spatial persona format they can press the digital crown

extension ViewModel {
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
                
                self.messenger = messenger
                
                groupSession.$state.sink {
                    // this Tearsdown existing group session
                    if case .invalidated = $0 {
                        self.messenger = nil
                        self.tasks.forEach { $0.cancel() }
                        self.tasks = []
                        self.subscriptions = []
                        //                        self.groupSession?.leave()
                        self.groupSession = nil
                        self.sharePlayEnabled = false
                    }
                }
                .store(in: &self.subscriptions)
                // store the subscription in the subscriptions set
                
                // sink observes and reacts to changes in the group session activeParticipants
                groupSession.$activeParticipants
                    .sink {
                        if $0.count >= 1 { self.activityState.mode = .sharePlay }
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
                        for await (message, _) in messenger.messages(of: ActivityState.self) {
                            self.receive(message)
                        }
                    }
                )
                
                
                
                /// For visionOS
                self.tasks.insert(
                    Task {
                        if let systemCoordinator = await groupSession.systemCoordinator {
                            for await localParticipantState in systemCoordinator.localParticipantStates {
                                // if it is spacial share play do something
                                
                            }
                        }
                    }
                )
                
                self.tasks.insert(
                    Task{
                        if let systemCoordinator = await groupSession.systemCoordinator {
                            for await immersionStyle in systemCoordinator.groupImmersionStyle{
                                if let immersionStyle {
                                    // open an immersive space with the same immersion style
                                } else{
                                    // Dismiss the immserive space
                                }
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
    func toggleSharePlay() {
        if (!self.sharePlayEnabled) {
            startSharePlay()
        } else {
            endSharePlay()
        }
    }
    
    func startSharePlay() {
        Task {
            let activity = MyGroupActivity()
            switch await activity.prepareForActivation() {
            case .activationPreferred:
                do {
                    _ = try await activity.activate()
                } catch {
                    print("SharePlay unable to activate the activity: \(error)")
                }
            case .activationDisabled:
                print("SharePlay group activity activation disabled")
            case .cancelled:
                print("SharePlay group activity activation cancelled")
            @unknown default:
                print("SharePlay group activity activation unknown case")
            }
        }
    }
    
    func endSharePlay() {
        self.groupSession?.end()
    }
    
    func sendMessage() {
        // sends the state of activity
        Task{
            try? await self.messenger?.send(self.activityState)
        }
    }
    func receive(_ message: ActivityState) {
        // receive the state of the activity and update the UI
        guard message.mode == .sharePlay else { return }
        Task{ @MainActor in
            self.activityState = message
            // after i get the new activity state i need to update the UI/Globe position
            updateUI()
        }
    }
    
    
    @MainActor
    private func updateUI() {
        // Loop through all the globe configurations and update the UI with animations. Either loop through globeConfigurations or entities
        for (globeId, configuration) in activityState.globeConfigurations {
            
            if let globeEntity = globeEntities[globeId] {
                let newTransform = activityState.globeEntities[globeId] // gets the new globeEntity from the activity
                
                // Careful since animateTransform also calls sendMessage this might cause a recursive loop thats why we use this
                globeEntity.animateTransformWithoutSendingMessage(
                    scale: newTransform?.scale.x,
                    orientation: newTransform?.orientation,
                    position: newTransform?.position,
                    duration: GlobeEntity.transformAnimationDuration
                )
            }
        }
    }
    
    
    //    func activateGroupActivity(){
    //        // activate the group activity
    //
    //        Task {
    //            do {
    //                let groupActivity = MyGroupActivity()
    //                switch await groupActivity.prepareForActivation() {
    //                case .activationPreferred:
    //                    let result = try await groupActivity.activate()
    //                    if result == false { throw Self.ActivationError.failed }
    //                case .activationDisabled:
    //                    throw Self.ActivationError.disabled
    //                case .cancelled:
    //                    throw Self.ActivationError.cancelled
    //                @unknown default:
    //                    throw Self.ActivationError.unknown
    //                }
    //            } catch {
    //                print("Failed activation: \(error)")
    //                assertionFailure()
    //            }
    //        }
    //    }
    //
    private func cleanupGroupSession() {
        // reset the group session, this is called when
        
        self.messenger = nil
        self.tasks.forEach { $0.cancel() }
        self.tasks = []
        self.subscriptions = []
        self.groupSession = nil
        self.activityState = ActivityState() // Reset activity state
        //           self.spatialSharePlaying = false // Reset spatialSharePlaying
    }
    
    private enum ActivationError: Error {
        case failed, disabled, cancelled, unknown
    }
}
