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
    
    func verticalFlippedImage() -> CIImage {
        let scaleTransform = CGAffineTransformMakeScale(1.0, -1.0)
        let translateTransform = CGAffineTransformMakeTranslation(0.0, self.extent.size.height)
        return imageByApplyingTransform(CGAffineTransformConcat(scaleTransform, translateTransform))
    }
    
    func scaledToResolution(resolution: CGSize) -> CIImage {
        if extent.size == resolution {
            return self;
        }
        let xScale = resolution.width / extent.size.width
        let yScale = resolution.height / extent.size.height
        let transformScale = CGAffineTransformMakeScale(xScale, yScale)
        return imageByApplyingTransform(transformScale)
    }
    
    func rotated90DegreesRight() -> CIImage {
        let translateTransform = CGAffineTransformMakeTranslation(-self.extent.size.width, 0.0)
        let rotateTransform = CGAffineTransformMakeRotation(CGFloat(-M_PI / 2))
        return imageByApplyingTransform(CGAffineTransformConcat(translateTransform, rotateTransform))
    }
    
}
