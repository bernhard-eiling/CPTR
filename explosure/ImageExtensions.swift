//
//  CGImageExtension.swift
//  CPTR
//
//  Created by Bernhard on 26.02.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import UIKit

extension CGImage {
    
    // replace with CIImage translations
    func rotate90Degrees(toSize size:CGSize, degrees: Double) -> CGImage {
        UIGraphicsBeginImageContext(CGSize(width: size.width , height: size.height))
        let context: CGContext? = UIGraphicsGetCurrentContext()
        CGContextTranslateCTM(context, size.width / 2, size.height / 2)
        CGContextRotateCTM(context, CGFloat(degrees))
        CGContextScaleCTM(context, 1.0, -1.0)
        CGContextTranslateCTM(context, -size.height / 2, -size.width / 2)
        CGContextDrawImage(context, CGRectMake(0, 0, size.height, size.width), self)
        UIGraphicsEndImageContext();
        return CGBitmapContextCreateImage(context!)!
    }
    
    
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
    
}
