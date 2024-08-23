//
//  SharePlayView.swift
//  Globes
//
//  Created by BooSung Jung on 14/8/2024.
//

import SwiftUI

struct SharePlayView: View {
    @Environment(ViewModel.self) var model
    var body: some View {
        Button(action: {
            model.toggleSharePlay()
        }, label: {
            model.sharePlayEnabled ? Text("Stop SharePlay") : Text("Start SharePlay")
        })
        .buttonStyle(.bordered).tint(model.sharePlayEnabled ? .green : .gray)
    }
}

#Preview {
    SharePlayView()
}
