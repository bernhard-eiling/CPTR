//
//  GAHelper.swift
//  CPTR
//
//  Created by Bernhard on 27.02.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import Foundation

class GAHelper {
    
    class func setup() {
        var configureError:NSError?
        GGLContext.sharedInstance().configureWithError(&configureError)
        assert(configureError == nil, "Error configuring Google services: \(configureError)")
        GAI.sharedInstance().trackUncaughtExceptions = true
//        GAI.sharedInstance().logger.logLevel = GAILogLevel.Verbose  // remove before app release
    }
    
    
    // EVENT TRACKING
    
    static let eventCategoryUserInteraction = "user-interaction"
    
    class func trackCompletePhotocapture() {
        GAHelper.trackEventWithCategory(eventCategoryUserInteraction, action: "complete-photo-capture")
    }
    
    class func trackPhotoSaved() {
        GAHelper.trackEventWithCategory(eventCategoryUserInteraction, action: "photo-saved")
    }
    
    private class func trackEventWithCategory(_ category: String, action: String) {
        let eventbuilder = GAIDictionaryBuilder.createEvent(withCategory: category, action: action, label: nil, value: nil)!
        guard let eventDictionary = (eventbuilder.build() as NSDictionary) as? [AnyHashable: Any] else { return }
        GAI.sharedInstance().defaultTracker.send(eventDictionary)
    }
    
    
    // VIEW TRACKING
    
    class func trackCameraView() {
        GAHelper.trackView("camera-view")
    }
    
    class func trackShareView() {
        GAHelper.trackView("share-view")
    }

    private class func trackView(_ viewName: String) {
        GAI.sharedInstance().defaultTracker.set(kGAIScreenName, value: viewName)
        let builder = GAIDictionaryBuilder.createScreenView()!
        guard let builderDictionary = (builder.build() as NSDictionary) as? [AnyHashable: Any] else { return }
        GAI.sharedInstance().defaultTracker.send(builderDictionary)
    }
}
