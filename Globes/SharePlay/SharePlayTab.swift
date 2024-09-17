//
//  SharePlayView.swift
//  Globes
//
//  Created by BooSung Jung on 14/8/2024.
//

import SwiftUI

struct SharePlayTab: View {
    @Environment(ViewModel.self) var model
    @Environment(\.openURL) private var openURL
    var body: some View {
        
        VStack(spacing: 48) {
#if DEBUG
            Button(action: {
                model.toggleSharePlay()
            }, label: {
                model.sharePlayEnabled ? Text("Stop SharePlay") : Text("Start SharePlay")
            })
            .buttonStyle(.bordered).tint(model.sharePlayEnabled ? .green : .gray)
#endif
 
            Text("To view globes with other people, start or join a FaceTime call. Then tap the button above this window to share globes.")
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
        }
    }
    
    
}

#Preview {
    SharePlayTab()
        .padding(50)
        .glassBackgroundEffect()
}
