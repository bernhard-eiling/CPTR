//
//  PhotoController.swift
//  explosure
//
//  Created by Bernhard Eiling on 17.10.15.
//  Copyright © 2015 bernhardeiling. All rights reserved.
//

import Foundation
import Photos

class PhotoController: NSObject {
    
    private let photoCapaciy = 2
    private var photoCounter = 0
    private var blendedPhoto: CGImage?

    private func saveImageToPhotoLibraryIfCapacityReached() {
        if (photoCounter < photoCapaciy) {
            return
        }
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
            let uiImage = UIImage(CGImage: self.blendedPhoto!)
            PHAssetCreationRequest.creationRequestForAssetFromImage(uiImage)
            }) { (success, error) -> Void in
                if (!success) {
                    NSLog("could not save image to photo library")
                } else {
                    self.photoCounter = 0
                }
        }
    }
    
    func addPhoto(photo: CGImage) {
        if blendedPhoto != nil {
            blendPhoto(photo)
            saveImageToPhotoLibraryIfCapacityReached()
        } else {
            blendedPhoto = photo
        }
    }
    
    func blendPhoto(photo: CGImage) {
        UIGraphicsBeginImageContext(sizeOfCGImage(photo))
        let context: CGContext? = UIGraphicsGetCurrentContext()
        CGContextDrawImage(context, rectOfCGImage(blendedPhoto!), blendedPhoto)
        CGContextSetBlendMode(context, .Normal)
        CGContextSetAlpha(context, 0.5)
        CGContextDrawImage(context, rectOfCGImage(photo), photo)
        blendedPhoto = CGBitmapContextCreateImage(context)
        photoCounter++
    }
    
    func sizeOfCGImage(image: CGImage) -> CGSize {
        return CGSize(width: CGImageGetWidth(image), height: CGImageGetHeight(image))
    }
    
    func rectOfCGImage(image: CGImage) -> CGRect {
        return CGRect(origin: CGPointZero, size: sizeOfCGImage(image))
    }
}