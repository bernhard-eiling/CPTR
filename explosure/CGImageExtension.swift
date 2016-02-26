//
//  CGImageExtension.swift
//  CPTR
//
//  Created by Bernhard on 26.02.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import Foundation
import UIKit

extension CGImage {

    func rotate90Degrees(toSize size:CGSize) -> CGImage {
        UIGraphicsBeginImageContext(CGSize(width: size.width , height: size.height))
        let context: CGContext? = UIGraphicsGetCurrentContext()
        CGContextTranslateCTM(context, size.width / 2, size.height / 2)
        CGContextRotateCTM(context, CGFloat(M_PI_2))
        CGContextScaleCTM(context, 1.0, -1.0)
        CGContextTranslateCTM(context, -size.height / 2, -size.width / 2)
        CGContextDrawImage(context, CGRectMake(0, 0, size.height, size.width), self)
        UIGraphicsEndImageContext();
        return CGBitmapContextCreateImage(context!)!
    }
    
    class func imageOrientationAccordingToDeviceOrientation() -> UIImageOrientation {
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
    
    func size() -> CGSize {
        return CGSize(width: CGImageGetWidth(self), height: CGImageGetHeight(self))
    }
    
    func rect() -> CGRect {
        return CGRect(origin: CGPointZero, size: self.size())
    }
}
