//
//  GaugeProgressStyle.swift
//  Globes
//
//  Created by Bernhard Jenny on 29/5/2024.
//

import SwiftUI

/// Custom progress style to override default of visionOS, which seems to always show indeterminate progress for circular progress views.
/// Based on https://www.hackingwithswift.com/quick-start/swiftui/customizing-progressview-with-progressviewstyle
struct GaugeProgressStyle: ProgressViewStyle {
    var strokeWidth = 2.0

    func makeBody(configuration: Configuration) -> some View {
        let fractionCompleted = configuration.fractionCompleted ?? 0
        return ZStack {
            Circle()
                .inset(by: strokeWidth / 2)
                .trim(from: 0, to: fractionCompleted)
                .stroke(.secondary, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
