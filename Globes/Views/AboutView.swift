//
//  AboutView.swift
//  Globes
//
//  Created by Bernhard Jenny on 20/3/2024.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    private static let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
    private let appVersion = Bundle.main.infoDictionary!["CFBundleShortVersionString" as String] as! String   
    private let authors = "Software development by Bernhard Jenny and Dilpreet Singh, Monash University.\nGlobe images and metadata by David Rumsey."
    private let copyright = "Copyright 2024 by Monash University, Melbourne, Australia and David Rumsey Map Center, Stanford Libraries, USA."
    private let license = "\(appName) source code is distributed under MIT license."
    private let sourceURL = URL(string: "https://github.com/berniejenny/Globes")!
    
    var body: some View {
        VStack {
            Image("icon")
                .resizable()
                .scaledToFit()
                .frame(height: 100)
            
            Text(Self.appName)
                .font(.title)
            Text(appVersion)
                .padding(.bottom)
            
            Group {
                Text(authors)
                    .padding(.bottom)
                Text(copyright)
                    .padding(.bottom)
                Text(license)
                Link("Source on GitHub", destination: sourceURL)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Label("Close", systemImage: "xmark")
            }
            .labelStyle(.iconOnly)
            .padding(.vertical)
        }
        .multilineTextAlignment(.center)
        .padding()
        .frame(width: 400, height: 550)
    }
}

#Preview {
    AboutView()
}
