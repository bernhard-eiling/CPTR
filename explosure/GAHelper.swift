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
        GAI.sharedInstance().logger.logLevel = GAILogLevel.Verbose  // remove before app release
    }
    
    
    // EVENT TRACKING
    
    static let eventCategoryUserInteraction = "user-interaction"
    
    class func trackCompletePhotocapture() {
        GAHelper.trackEventWithCategory(eventCategoryUserInteraction, action: "complete-photo-capture")
    }
    
    class func trackPhotoSaved() {
        GAHelper.trackEventWithCategory(eventCategoryUserInteraction, action: "photo-saved")
    }
    
    private class func trackEventWithCategory(category: String, action: String) {
        let eventbuilder = GAIDictionaryBuilder.createEventWithCategory(category, action: action, label: nil, value: nil)
        GAI.sharedInstance().defaultTracker.send(eventbuilder.build() as [NSObject : AnyObject])
    }
    
    
    // VIEW TRACKING
    
    class func trackCameraView() {
        GAHelper.trackView("camera-view")
    }
    
    class func trackShareView() {
        GAHelper.trackView("share-view")
    }

    private class func trackView(viewName: String) {
        GAI.sharedInstance().defaultTracker.set(kGAIScreenName, value: viewName)
        let builder = GAIDictionaryBuilder.createScreenView()
        GAI.sharedInstance().defaultTracker.send(builder.build() as [NSObject : AnyObject])
    }
}
