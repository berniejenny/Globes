//
//  SharePlayView.swift
//  Globes
//
//  Created by BooSung Jung on 19/7/2024.
//


import SwiftUI
import GroupActivities
import Combine


struct SharePlayView: View {
    
    @State private var groupSession: GroupSession<MyGroupActivity>? = nil
  
    
    var body: some View {
        VStack{
            if let _ = groupSession{
                Text("Connected to sharePlay session")
            }
            else{
                Button{
                    startSharePlay()
                } label:{
                    Label("Start activity", systemImage: "shareplay")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear{
            observeSessions()
        }
    }
    
    
    /// function to initialise share play
    @MainActor
    private func startSharePlay() {
        
        Task {
            do {
                _ = try await MyGroupActivity().activate()
            } catch {
                print("Failed to start SharePlay: \(error)")
            }
        }
    }
    
    /// function that is called the moment this view is created
    private func observeSessions() {
        Task {
            for await session in MyGroupActivity.sessions() {
                guard let systemCoordinator = await session.systemCoordinator else {continue}
                
                // Check if local participant is spatial
                let isLocalParticipantSpatial = systemCoordinator.localParticipantState.isSpatial
                
                // Set up spacial configuration
                var configuration = SystemCoordinator.Configuration()
                configuration.spatialTemplatePreference = .none
                systemCoordinator.configuration = configuration
                
                //TODO: Sync globe rotation and zoom with other participants
                
                Task.detached{
                    for await localParticipantState in systemCoordinator.localParticipantStates {
                        if localParticipantState.isSpatial{
                            // start syncing scroll position
                        } else{
                            // stop syncing scroll position
                        }
                    }
                }
               
                session.join()
            }
        }
    }
    
    /// function to handle session state changes
    @MainActor
    private func handleSessionStateChange(_ state: GroupSession<MyGroupActivity>.State) {
            switch state {
            case .waiting:
                print("Session is waiting for more participants")
            case .joined:
                print("Session is playing")
            case .invalidated(let error):
                print("Session invalidated with error: \(String(describing: error))")
                self.groupSession = nil
            default:
                break
            }
        }
}

#if DEBUG
#Preview {
    SharePlayView()
}

#endif
