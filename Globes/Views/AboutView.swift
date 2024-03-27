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
    private let authors: LocalizedStringKey = "Software development by [Bernhard Jenny](https://berniejenny.info) and [Dilpreet Singh](https://dilpreet.co), Monash University.\nGlobe images and metadata by [David Rumsey](https://www.davidrumsey.com)."
    private let copyright: LocalizedStringKey = "Copyright 2024 by Monash University, Melbourne, Australia and [David Rumsey Map Center](https://library.stanford.edu/libraries/david-rumsey-map-center), Stanford Libraries, USA."
    private let license: LocalizedStringKey = "Source code under MIT license on [GitHub](https://github.com/berniejenny/Globes)"
    
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
//                Text(license)
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
