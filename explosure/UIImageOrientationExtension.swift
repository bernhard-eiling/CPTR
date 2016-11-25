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
        switch UIDevice.current.orientation {
        case .portrait:
            return .right
        case .landscapeLeft:
            return .up
        case .landscapeRight:
            return .down
        case .portraitUpsideDown:
            return .left
        default:
            return .right
        }
    }
    
}
