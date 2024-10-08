//
//  SharePlayView.swift
//  Globes
//
//  Created by BooSung Jung on 14/8/2024.
//

import SwiftUI
import GroupActivities
import _GroupActivities_UIKit

struct SharePlayTab: View {
    @Environment(ViewModel.self) var model
    @Environment(\.openURL) private var openURL
    @StateObject private var groupStateObserver = GroupStateObserver()
    @State private var sharingController: Bool = false
    @State private var groupActivityReady: Bool = false
    @ObservedObject var logStore = LogStore.shared
    
    var body: some View {
        
        VStack(spacing: 48){
            
            Text("SharePlay").font(.title)
            
            Text("To view globes with other people, start or join a FaceTime call. Then tap the button above this window to share globes. To enter a more immersive experience, press the cube \(Image(systemName: "cube")) button in FaceTime call settings. Or start a sharePlay session with a friend by tapping 'Contact your friends' below.")
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 400)
                        Button {
                            if let url = URL(string: "https://support.apple.com/en-au/guide/apple-vision-pro/tan440238696/visionos") {
                                openURL(url)
                            }
                        } label: {
                            Label("Learn how to make a FaceTime call", image: "person.3.fill")
                                .fixedSize()
                        }
#if !DEBUG
            Section{
                Button{
                    self.sharingController = true
                } label: {
                    Label{
                        Text("Contact your friends")
                    } icon: {
                        Image(systemName: "person.badge.plus")
                    }
                }
                
                
            } header: {
                Text("Start SharePlay with friends").font(.headline)
            }
            .sheet(isPresented: self.$sharingController) {
                Self.SharingControllerView(self.$groupActivityReady)
            }
            .onChange(of: groupStateObserver.isEligibleForGroupSession) { _, newValue in
                if newValue {
                    if self.groupActivityReady {
                        model.startSharePlay()
                        self.groupActivityReady = false
                    }
                }
            }
            #else
            Button(action: {
                model.toggleSharePlay()
            }, label: {
                
                    model.sharePlayEnabled ? Text("Stop SharePlay") : Text("Start SharePlay")
                
            })
            .buttonStyle(.bordered)
            .tint(model.sharePlayEnabled ? .green : .gray)

#endif
            
        }
    }
    #if !DEBUG
    //https://developer.apple.com/documentation/groupactivities/groupactivitysharingcontroller-ybcy
    private struct SharingControllerView: UIViewControllerRepresentable {
        private let groupActivityShareController: GroupActivitySharingController
        @Binding var groupActivityReady: Bool
        
       
        func makeUIViewController(context: Context) -> GroupActivitySharingController {
            Task {
                switch await self.groupActivityShareController.result {
                case .success:
                    print("groupActivityShareController.result: success")
                    self.groupActivityReady = true
                case .cancelled:
                    print("groupActivityShareController.result: cancelled")
                @unknown default:
                    assertionFailure()
                }
            }
            return self.groupActivityShareController
        }
        
        func updateUIViewController(_ uiViewController: GroupActivitySharingController, context: Context) {
            print("🖨️ updateUIViewController/context", context)
        }
        
        init?(_ groupActivityEnabled: Binding<Bool>){
            do{
                self.groupActivityShareController = try GroupActivitySharingController(MyGroupActivity())
            } catch {
                return nil
            }
            self._groupActivityReady = groupActivityEnabled
        }
    }
    #endif
    
}







#Preview {
    SharePlayTab()
        .padding(50)
        .glassBackgroundEffect()
}
