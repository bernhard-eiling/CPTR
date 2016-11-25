//
//  CGImageExtension.swift
//  CPTR
//
//  Created by Bernhard on 26.02.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import UIKit

extension CGImage {

    func size() -> CGSize {
        return CGSize(width: self.width, height: self.height)
    }
    
    func rect() -> CGRect {
        return CGRect(origin: CGPoint.zero, size: self.size())
    }
    
}

extension CIImage {
    
    func horizontalFlippedImage() -> CIImage {
        let scaleTransform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        let translateTransform = CGAffineTransform(translationX: extent.size.width, y: 0.0)
        return applying(scaleTransform.concatenating(translateTransform))
    }
    
    func verticalFlippedImage() -> CIImage {
        let scaleTransform = CGAffineTransform(scaleX: 1.0, y: -1.0)
        let translateTransform = CGAffineTransform(translationX: 0.0, y: extent.size.height)
        return applying(scaleTransform.concatenating(translateTransform))
    }
    
    func scale(toResolution resolution: CGSize) -> CIImage {
        guard extent.size != resolution else { return self }
        let xScale = resolution.width / extent.size.width
        let yScale = resolution.height / extent.size.height
        let transformScale = CGAffineTransform(scaleX: xScale, y: yScale)
        return applying(transformScale)
    }
    
    func rotated90DegreesRight() -> CIImage {
        let translateTransform = CGAffineTransform(translationX: -extent.size.width, y: 0.0)
        let rotateTransform = CGAffineTransform(rotationAngle: CGFloat(-M_PI_2))
        return applying(translateTransform.concatenating(rotateTransform))
    }
    
    func scale(toView view: UIView) -> CIImage {
        let imageFitsGLView = view.bounds.width * view.contentScaleFactor == extent.width && view.bounds.height * view.contentScaleFactor == extent.height
        if !imageFitsGLView {
            return scale(toResolution: CGSize(width: view.bounds.width * view.contentScaleFactor, height: view.bounds.height * view.contentScaleFactor))
        }
        return self;
    }
    
}
