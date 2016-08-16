//
//  UpsideRotationView.swift
//  CPTR
//
//  Created by Bernhard Eiling on 16.08.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import UIKit

class UpsideRotationViewsHandler {
    
    private let upsideRotationViews: [UIView]
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    init(withViews upsideRotationViews: [UIView]) {
        self.upsideRotationViews = upsideRotationViews
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(deviceOrientationDidChange), name: UIDeviceOrientationDidChangeNotification, object: nil)
    }
    
    @objc private func deviceOrientationDidChange() {
        switch UIDevice.currentDevice().orientation {
        case .Portrait:
            rotateRotatableViewsWithTransform(CGAffineTransformIdentity)
            break
        case .LandscapeLeft:
            rotateRotatableViewsWithTransform(CGAffineTransformMakeRotation(CGFloat(M_PI_2)))
            break
        case .LandscapeRight:
            rotateRotatableViewsWithTransform(CGAffineTransformMakeRotation(-CGFloat(M_PI_2)))
            break
        case .PortraitUpsideDown:
            rotateRotatableViewsWithTransform(CGAffineTransformMakeRotation(CGFloat(M_PI)))
            break
        default:
            break
        }
    }
    
    private func rotateRotatableViewsWithTransform(transform: CGAffineTransform) {
        UIView.animateWithDuration(0.3) { () -> Void in
            for rotatableView in self.upsideRotationViews {
                rotatableView.transform = transform
            }
        }
    }
    
}
