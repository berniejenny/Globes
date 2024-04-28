//
//  AppStore.swift
//  Globes
//
//  Created by Bernhard Jenny on 28/04/2024.
//

import Foundation
import StoreKit

struct AppStore {
    private init() {}
    
    /// App Store URL
    static var url = URL(string: "https://apps.apple.com/au/app/globes/id6480082996")!
    
    /// URL for reviewing the app on the App Store
    /// https://developer.apple.com/documentation/storekit/requesting_app_store_reviews
    static var writeReviewURL = URL(string: "https://apps.apple.com/au/app/globes/id6480082996?action=write-review")!
    
    /// Prompt the user to provide a review on the app store once a number of globes have been created. Schedules a maximum of 3 requests per year.
    ///
    /// The current UI shows small globes that intersect the dialog prompting for reviews. The globes can be hidden before the dialog is shown,
    /// but it is not clear how a notification can be received to show them again. For the moment, `promptReview` is therefore always false, such that the dialog is not shown.
    /// - Parameter promptReview: Only prompt for review if true.
    static func increaseGlobesCount(promptReview: Bool) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        
        // require 10 shading exports since the last request for a review
        let minNumberOfGlobesBetweenRequests = 25
        
        // up to three requests within a 365-day period are possible https://developer.apple.com/app-store/ratings-and-reviews/
        let minDaysBetweenRequests = 365 / 4
        
        // keys for user defaults
        let numberOfGlobesKey = "numberOfGlobes"
        let numberOfGlobesAtLastRequestKey = "numberOfGlobesAtLastReviewRequest"
        let lastRequestDateKey = "lastReviewRequestDate"
        
        // retrieve and increase number of globes
        var numberOfGlobes = UserDefaults.standard.integer(forKey: numberOfGlobesKey)
        numberOfGlobes += 1
        UserDefaults.standard.set(numberOfGlobes, forKey: numberOfGlobesKey)
        
        guard promptReview else { return }
        
        // Retrieve days since last request from user defaults.
        // If a request has never happened, assume a request in a distance past,
        // such that the first request is shown after the first `minNumberOfGlobesBetweenRequests` exports.
        let lastRequestDate = (UserDefaults.standard.object(forKey: lastRequestDateKey) as? Date) ?? .distantPast
        let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: .now).day
        
        // compute number of globes created since last request
        let numberOfGlobesAtLastRequest = UserDefaults.standard.integer(forKey: numberOfGlobesAtLastRequestKey)
        let numberOfGlobesSinceLastRequest = numberOfGlobes - numberOfGlobesAtLastRequest
        
        if let daysSinceLastRequest,
           daysSinceLastRequest > minDaysBetweenRequests,
           numberOfGlobesSinceLastRequest > minNumberOfGlobesBetweenRequests {
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // delay is necessary
                if let currentScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: currentScene)
                }
            }
            
            // store date of current request
            UserDefaults.standard.set(Date.now, forKey: lastRequestDateKey)
            // store number of globes created as of current request
            UserDefaults.standard.set(numberOfGlobes, forKey: numberOfGlobesAtLastRequestKey)
        }
    }
}
