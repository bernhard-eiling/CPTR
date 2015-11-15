//
//  PhotoController.swift
//  explosure
//
//  Created by Bernhard Eiling on 17.10.15.
//  Copyright © 2015 bernhardeiling. All rights reserved.
//

import Foundation
import Photos

@objc protocol PhotoControllerDelegate {
    optional func blendedPhotoDidChange(blendedPhoto: CGImage?)
    optional func photoSavedToPhotoLibrary(savedUIImage: UIImage)
}

class PhotoController: NSObject {
    
    var isSavingPhoto: Bool
    private let photoCapaciy = 2
    private var photoCounter = 0
    private var blendedPhoto: CGImage?
    private var rotatedUIImage: UIImage?
    var cameraControllerDelegate: PhotoControllerDelegate?
    var cameraViewControllerDelegate: PhotoControllerDelegate?
    var localIdentifier: String?
    
    override init() {
        isSavingPhoto = false
        super.init()
    }
    
    private func saveImageToPhotoLibrary() {
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
            self.rotatedUIImage = self.rotatedImageAccordingToDeviceOrientation(self.blendedPhoto!)
            PHAssetCreationRequest.creationRequestForAssetFromImage(self.rotatedUIImage!)
            }) { (success, error) -> Void in
                self.isSavingPhoto = false
                if (!success) {
                    NSLog("could not save image to photo library")
                } else {
                    let notRotImage = UIImage(CGImage: self.blendedPhoto!)
                    self.cameraControllerDelegate?.blendedPhotoDidChange?(self.blendedPhoto)
                    self.cameraControllerDelegate?.photoSavedToPhotoLibrary?(self.rotatedUIImage!)
                    self.cameraViewControllerDelegate?.photoSavedToPhotoLibrary?(notRotImage)
                    self.photoCounter = 0
                    self.blendedPhoto = nil
                    NSLog("image saved to photo library")
                }
        }
        
    }
    
    func rotatedImageAccordingToDeviceOrientation(image: CGImage) -> UIImage { // does not actual pixel rotation?
        var imageOrientation: UIImageOrientation?
        if (UIDevice.currentDevice().orientation == .Portrait) {
            imageOrientation = .Right
        } else if (UIDevice.currentDevice().orientation == .LandscapeLeft) {
            imageOrientation = .Up
        } else if (UIDevice.currentDevice().orientation == .LandscapeRight) {
            imageOrientation = .Down
        } else {
            imageOrientation = .Left
        }
        return UIImage(CGImage: image, scale: 1.0, orientation: imageOrientation!);
    }
    
    func addPhoto(photo: CGImage) {
        if (photoCounter >= photoCapaciy) {
            NSLog("photo capacity reached")
            return
        }
        self.photoCounter++
        NSLog ("photo count: %i", photoCounter)
        if blendedPhoto != nil {
            blendPhoto(photo)
        } else {
            blendedPhoto = photo
            isSavingPhoto = false
            self.cameraControllerDelegate?.blendedPhotoDidChange?(blendedPhoto)
        }
    }
    
    private func blendPhoto(photo: CGImage) {
        let sessionQueue = dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)
        dispatch_async(sessionQueue) { () -> Void in
            UIGraphicsBeginImageContext(self.sizeOfCGImage(photo))
            let context: CGContext? = UIGraphicsGetCurrentContext()
            CGContextScaleCTM(context, 1.0, -1.0)
            CGContextTranslateCTM(context, 0.0, -CGFloat(CGImageGetHeight(photo)))
            CGContextDrawImage(context, self.rectOfCGImage(self.blendedPhoto!), self.blendedPhoto)
            CGContextSetBlendMode(context, .Normal)
            CGContextSetAlpha(context, 0.5)
            CGContextDrawImage(context, self.rectOfCGImage(photo), photo)
            self.blendedPhoto = CGBitmapContextCreateImage(context)
            UIGraphicsEndImageContext();
            
            self.cameraControllerDelegate?.blendedPhotoDidChange?(self.blendedPhoto)
            if (self.photoCounter >= self.photoCapaciy) {
                self.saveImageToPhotoLibrary()
            }
        }
    }
    
    func sizeOfCGImage(image: CGImage) -> CGSize {
        return CGSize(width: CGImageGetWidth(image), height: CGImageGetHeight(image))
    }
    
    func rectOfCGImage(image: CGImage) -> CGRect {
        return CGRect(origin: CGPointZero, size: sizeOfCGImage(image))
    }
}