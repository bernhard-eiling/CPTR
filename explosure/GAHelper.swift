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

}
