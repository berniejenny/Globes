//
//  DismissButton.swift
//  Globes
//
//  Created by Bernhard Jenny on 23/5/2024.
//

import SwiftUI

struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Button(action: { dismiss() }, label: {
            Image(systemName: "xmark")
        })
        .buttonBorderShape(.circle)
        .help("Close")
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    DismissButton()
        .padding()
        .glassBackgroundEffect()
}
