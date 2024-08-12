//
//  SharePlay.swift
//  Globes
//
//  Created by BooSung Jung on 31/7/2024.
//

import SharePlayMock
import GroupActivities

extension ViewModel {
    func toggleEnlarge() {
        enlarged.toggle()
        sendState(ActivityState(enlarged: enlarged))
    }
    func sendState(_ message: ActivityState) {
        Task {
            do {
                try await sharePlayMessenger?.send(message)
            } catch {
                print("sendEnlargeMessage failed \(error)")
            }
        }
    }
    
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
        self.sharePlayGroupSession?.end()
    }
    
    func configureGroupSessions(){
        Task{
            for await groupSession in MyGroupActivity.sessions() {
                self.sharePlayGroupSession = groupSession
                let messenger = GroupSessionMessengerMock(session: groupSession)
                self.sharePlayMessenger = messenger
                
                groupSession.$state.sink {
                    if case .invalidated = $0{
                        self.sharePlayMessenger = nil
                        self.tasks.forEach{$0.cancel()}
                        self.tasks = []
                        self.subscriptions = []
                        self.sharePlayGroupSession = nil
                        self.sharePlayEnabled = false
                    }
                }
                .store(in: &self.subscriptions)
                
                groupSession.$activeParticipants
                    .sink {
                        if $0.count > 0{
                            self.activityState.mode = .sharePlay
                        }
                        let newParticipants = $0.subtracting(groupSession.activeParticipants)
                        Task { @MainActor in
                            try? await messenger.send(ActivityState(enlarged: self.enlarged),
                                                      to: .only(newParticipants))
                        }
                    }
                    .store(in: &self.subscriptions)
                
                self.tasks.insert(
                    Task{
                        for await (message, _) in messenger.messages(of: ActivityState.self){
                            self.receive(message)
                        }
                    }
                )
                
                
                

                
                self.tasks.insert(
                    Task {
                        if let systemCoordinator = await groupSession.systemCoordinator {
                            // not working because i am using the mock version
                            //                            for await immersionStyle in systemCoordinator.groupImmersionStyle {
                            //                                if immersionStyle != nil {
                            //                                    self.queueToOpenScene = .fullSpace
                            //                                } else {
                            //                                    self.queueToOpenScene = .volume
                            //                                }
                            //                            }
                        }
                    }
                )
                
                // set the configuration of the system coordinator
                
                self.tasks.insert(
                    Task {
                        if let systemCoordinator = await groupSession.systemCoordinator {
                            var configuration = SystemCoordinator.Configuration()
                            configuration.supportsGroupImmersiveSpace = true
//                            if #available(visionOS 2.0, *) {
//                                configuration.spatialTemplatePreference = .surround
//                            }
                            systemCoordinator.configuration = configuration
                            groupSession.join()
                        }
                    }
                )
                groupSession.join()
            }
            
            
        }
    }
    
    private func receive(_ message: ActivityState) {
        guard message.mode == .sharePlay else { return }
        Task { @MainActor in
            self.activityState = message
        }
    }
}
