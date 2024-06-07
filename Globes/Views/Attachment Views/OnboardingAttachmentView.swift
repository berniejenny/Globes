//
//  OnboardingAttachmentView.swift
//  Globes
//
//  Created by Bernhard Jenny on 6/6/2024.
//

import SwiftUI

struct OnboardingAttachmentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Tap this globe to show and hide information and controls.")
            Text("To position a globe, pinch and drag with one hand.")
            Text("To resize a globe, pinch and drag with both hands.")
            Text("Double-tap to stop and start the automatic rotation.")
        }
        .padding()
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false) // let gestures pass through
    }
}

#Preview {
    OnboardingAttachmentView()
}
