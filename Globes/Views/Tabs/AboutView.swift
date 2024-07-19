//
//  AboutView.swift
//  Globes
//
//  Created by Bernhard Jenny on 20/3/2024.
//

import SwiftUI

struct HelpView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Help")
                .font(.title3)
            Text("Look at a globe and tap to show information and controls.")
            Text("To position a globe, pinch and drag with one hand.")
            Text("To resize a globe, pinch and drag with both hands.")
            Text("To rotate a globe, pinch with one hand, hold for a moment and then drag. Or, pinch and rotate with both hands.")
            Text("Double-tap to stop and start the automatic rotation.")
        }
    }
}

struct CreditsView: View {
    private static let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
    private let appVersion = Bundle.main.infoDictionary!["CFBundleShortVersionString" as String] as! String
    private let authors: LocalizedStringKey = "Software development by [Bernhard Jenny](https://berniejenny.info) and [Dilpreet Singh](https://dilpreet.co), Monash University.\nGlobe images and metadata by [David Rumsey](https://www.davidrumsey.com)."
    private let copyright: LocalizedStringKey = "Copyright 2024 by Monash University, Melbourne, Australia and [David Rumsey Map Center](https://library.stanford.edu/libraries/david-rumsey-map-center), Stanford Libraries, USA."
    private let license: LocalizedStringKey = "Source code under MIT license on [GitHub](https://github.com/berniejenny/Globes)"
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("About")
                .font(.title3)
            Text(authors)
            Text(copyright)
            // Text(license) // TBD: increase frame height when license is shown
        }
    }
}

struct AboutView: View {
    @Environment(\.openURL) var openURL
    @ScaledMetric private var scaledHWidth = 450.0
    @ScaledMetric private var scaledVWidth = 600.0
    
    private static let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
    private let appVersion = Bundle.main.infoDictionary!["CFBundleShortVersionString" as String] as! String
    
    private let iconSize: Double = 80
    
    var body: some View {
        VStack {
            ZStack {
                Image("AppIcon/Back/Content")
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .mask {
                        Circle()
                    }
                //                Image("AppIcon/Middle/Content")
                //                    .resizable()
                //                    .frame(width: iconSize, height: iconSize)
                Image("AppIcon/Front/Content")
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .offset(z: 5)
            }
            .padding()
            
            Text(Self.appName)
                .font(.title)
            Text(appVersion)
                .padding(.bottom, 6)
            
            Text("Globes at the David Rumsey Map Center, Stanford Libraries")
                .padding(.bottom)
            
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 40) {
                    HelpView()
                        .frame(width: scaledHWidth)
                    CreditsView()
                        .frame(width: scaledHWidth)
                }
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top)
                
                VStack {
                    HelpView()
                    CreditsView()
                        .padding(.top)
                }
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: scaledVWidth)
            }
            .allowsTightening(true)
            
            Spacer(minLength: 0)
            
            Button(action: { openURL(AppStore.writeReviewURL) }) {
                Label("Review Globes", systemImage: "star")
            }
        }
        .padding(.top, 20)
        .padding()
    }
        
}

#Preview {
    AboutView()
        .padding()
        .glassBackgroundEffect()
}
