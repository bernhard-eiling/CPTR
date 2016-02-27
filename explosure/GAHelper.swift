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

        GAI.sharedInstance().trackUncaughtExceptions = true  // report uncaught exceptions
        GAI.sharedInstance().logger.logLevel = GAILogLevel.Verbose  // remove before app release
    }
    
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
