//
//  Error.swift
//  Globes
//
//  Created by Bernhard Jenny on 5/4/2024.
//

import Foundation

/// Returns a throwable NSError with a message and an optional secondary message.
/// - Parameters:
///   - errorMessage: Error message to display to user.
///   - secondaryMessage: A string that can be displayed as the secondary message on an alert panel.
/// - Returns: Error
func error(_ errorMessage: String, secondaryMessage: String? = nil) -> NSError {
    let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
    
    var userInfo = [NSLocalizedDescriptionKey: errorMessage]
    if let secondaryMessage = secondaryMessage {
        userInfo[NSLocalizedRecoverySuggestionErrorKey] = secondaryMessage
    }
    
    return NSError(domain: appName, code: 0, userInfo: userInfo)
}

extension Error {
    
    /// Secondary message for an alert dialog constructed from the recovery suggestion and the failure reason of this error.
    var alertSecondaryMessage: String? {
        let nsError = self as NSError // bridge from Swift Error to NSError
        var secondaryMessage: String? = nil
        if let recoverySuggestion = nsError.localizedRecoverySuggestion {
            secondaryMessage = recoverySuggestion
        }
        if let failureReason = nsError.localizedFailureReason {
            secondaryMessage = secondaryMessage == nil ? failureReason : secondaryMessage! + "\n" + failureReason
        }
        return secondaryMessage
    }
}
