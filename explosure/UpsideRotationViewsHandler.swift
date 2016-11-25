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
        NotificationCenter.default.removeObserver(self)
    }
    
    init(withViews upsideRotationViews: [UIView]) {
        self.upsideRotationViews = upsideRotationViews
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationDidChange), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }
    
    @objc fileprivate func deviceOrientationDidChange() {
        switch UIDevice.current.orientation {
        case .portrait:
            rotateRotatableViewsWithTransform(CGAffineTransform.identity)
            break
        case .landscapeLeft:
            rotateRotatableViewsWithTransform(CGAffineTransform(rotationAngle: CGFloat(M_PI_2)))
            break
        case .landscapeRight:
            rotateRotatableViewsWithTransform(CGAffineTransform(rotationAngle: -CGFloat(M_PI_2)))
            break
        case .portraitUpsideDown:
            rotateRotatableViewsWithTransform(CGAffineTransform(rotationAngle: CGFloat(M_PI)))
            break
        default:
            break
        }
    }
    
    private func rotateRotatableViewsWithTransform(_ transform: CGAffineTransform) {
        UIView.animate(withDuration: 0.3, animations: { () -> Void in
            for rotatableView in self.upsideRotationViews {
                rotatableView.transform = transform
            }
        }) 
    }
    
}
