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
        return CGSize(width: CGImageGetWidth(self), height: CGImageGetHeight(self))
    }
    
    func rect() -> CGRect {
        return CGRect(origin: CGPointZero, size: self.size())
    }
    
}

extension CIImage {
    
    func horizontalFlippedImage() -> CIImage {
        let scaleTransform = CGAffineTransformMakeScale(-1.0, 1.0)
        let translateTransform = CGAffineTransformMakeTranslation(extent.size.width, 0.0)
        return imageByApplyingTransform(CGAffineTransformConcat(scaleTransform, translateTransform))
    }
    
    func verticalFlippedImage() -> CIImage {
        let scaleTransform = CGAffineTransformMakeScale(1.0, -1.0)
        let translateTransform = CGAffineTransformMakeTranslation(0.0, extent.size.height)
        return imageByApplyingTransform(CGAffineTransformConcat(scaleTransform, translateTransform))
    }
    
    func scaledToResolution(resolution: CGSize) -> CIImage {
        guard extent.size != resolution else { return self }
        let xScale = resolution.width / extent.size.width
        let yScale = resolution.height / extent.size.height
        let transformScale = CGAffineTransformMakeScale(xScale, yScale)
        return imageByApplyingTransform(transformScale)
    }
    
    func rotated90DegreesRight() -> CIImage {
        let translateTransform = CGAffineTransformMakeTranslation(-extent.size.width, 0.0)
        let rotateTransform = CGAffineTransformMakeRotation(CGFloat(-M_PI_2))
        return imageByApplyingTransform(CGAffineTransformConcat(translateTransform, rotateTransform))
    }
    
}
