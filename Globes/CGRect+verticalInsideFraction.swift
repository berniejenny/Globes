//
//  CGRect+verticalInsideFraction.swift
//  Globes
//
//  Created by Bernhard Jenny on 18/6/2024.
//

import Foundation

extension CGRect {
    
    /// Returns a value between 0 and 1 indicating the vertical fraction of an `inner` frame that is inside an `outer` frame.
    /// - Parameters:
    ///   - innerFrame: Inner frame
    ///   - outerFrame: Outer frame
    /// - Returns: Value between 0 and 1.
    static func verticalInsideFraction(_ innerFrame: CGRect, _ outerFrame: CGRect) -> Double {
        var visibleFraction: Double = 1
        if innerFrame.maxY > outerFrame.maxY {
            // inner frame is partially outside the outer frame at the bottom
            visibleFraction = (outerFrame.maxY - innerFrame.minY) / innerFrame.height
        } else if innerFrame.minY < outerFrame.minY {
            // at the top
            visibleFraction = Double(innerFrame.minY / innerFrame.height) + 1
        }
        return min(max(visibleFraction, 0), 1)
    }
}
