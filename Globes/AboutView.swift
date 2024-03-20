//
//  AboutView.swift
//  Globes
//
//  Created by Bernhard Jenny on 20/3/2024.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    private let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
    
    private let appVersion = Bundle.main.infoDictionary!["CFBundleShortVersionString" as String] as! String
    
    private let authors = "Software development by Bernhard Jenny and Dilpreet Singh, Monash University.\nGlobe images and metadata by David Rumsey."
    private let copyright = "Copyright 2024 by Monash University, Melbourne, Australia and David Rumsey, USA."
    
    var body: some View {
        VStack(spacing: 10) {            
            Image("icon")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
            
            Text(appName)
                .font(.title)
            Text(appVersion)
            
            Group {
                Text(authors)
                Text(copyright)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            
            Button(action: { dismiss() }) {
                Label("Close", systemImage: "xmark")
            }
            .labelStyle(.iconOnly)
            .padding(.vertical)
        }
        .multilineTextAlignment(.center)
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    AboutView()
}
