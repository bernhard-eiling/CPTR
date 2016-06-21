//
//  UIImageOrientationExtension.swift
//  CPTR
//
//  Created by Bernhard Eiling on 21.06.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import UIKit

extension UIImageOrientation {
    
    static func relationToDeviceOrientaton() -> UIImageOrientation {
        switch UIDevice.currentDevice().orientation {
        case .Portrait:
            return .Right
        case .LandscapeLeft:
            return .Up
        case .LandscapeRight:
            return .Down
        case .PortraitUpsideDown:
            return .Left
        default:
            return .Right
        }
    }
    
}
