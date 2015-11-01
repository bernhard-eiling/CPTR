//
//  PhotoController.swift
//  explosure
//
//  Created by Bernhard Eiling on 17.10.15.
//  Copyright © 2015 bernhardeiling. All rights reserved.
//

import Foundation
import Photos

protocol PhotoControllerDelegate {
    func photoDidBlend(blendedPhoto: CGImage)
}

class PhotoController: NSObject {
    
    private let photoCapaciy = 2
    private var photoCounter = 0
    private var blendedPhoto: CGImage?
    var delegate: PhotoControllerDelegate?
    
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
                    NSLog("image saved to photo library")
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
        let sessionQueue = dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)
        dispatch_async(sessionQueue) { () -> Void in
            UIGraphicsBeginImageContext(self.sizeOfCGImage(photo))
            let context: CGContext? = UIGraphicsGetCurrentContext()
            CGContextDrawImage(context, self.rectOfCGImage(self.blendedPhoto!), self.blendedPhoto)
            CGContextSetBlendMode(context, .Normal)
            CGContextSetAlpha(context, 0.5)
            CGContextDrawImage(context, self.rectOfCGImage(photo), photo)
            self.blendedPhoto = CGBitmapContextCreateImage(context)
            UIGraphicsEndImageContext();
            
            self.photoCounter++

            self.delegate?.photoDidBlend(self.blendedPhoto!)
        }
        
        
    }
    
    func sizeOfCGImage(image: CGImage) -> CGSize {
        return CGSize(width: CGImageGetWidth(image), height: CGImageGetHeight(image))
    }
    
    func rectOfCGImage(image: CGImage) -> CGRect {
        return CGRect(origin: CGPointZero, size: sizeOfCGImage(image))
    }
}