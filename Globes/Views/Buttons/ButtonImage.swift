//
//  ButtonImage.swift
//  Globes
//
//  Created by Bernhard Jenny on 16/5/2024.
//

import SwiftUI

struct ButtonImage: View {
    let name: String
    var isSystemImage = true
    
    @ScaledMetric private var size = 22.0
    
    var body: some View {
        let image = isSystemImage ? Image(systemName: name) : Image(name)
        return image
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .padding(10)
    }
}

#if DEBUG
#Preview {
    struct PreviewWrapper: View {
        @State var rotation: Bool = true
        
        var body: some View {
            HStack {
                ButtonImage(name: "rotate.3d")
                    .padding()
                ButtonImage(name: "rotate.3d.slash", isSystemImage: false)
                    .padding()
                
                Button(action: { rotation.toggle() } ) {
                    if rotation {
                        ButtonImage(name: "rotate.3d")
                    } else {
                        ButtonImage(name: "rotate.3d.slash", isSystemImage: false)
                    }
                }
                .buttonStyle(.plain)
                .buttonBorderShape(.circle)
            }
            .padding()
            .glassBackgroundEffect()
        }
    }
    return PreviewWrapper()
}
#endif
