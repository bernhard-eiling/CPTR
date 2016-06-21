//
//  StillImageController.swift
//  CPTR
//
//  Created by Bernhard Eiling on 12.06.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import AVFoundation
import Photos

class StillImageController {
    
    var captureDevice: AVCaptureDevice?
    private(set) var compoundImage: CompoundImage
    
    private let ciContext: CIContext
    private let maxStillImageResolution: CGSize
    private let stillImageBlendFilter: Filter
    
    init?(ciContext: CIContext, captureDevice: AVCaptureDevice) {
        self.ciContext = ciContext
        self.captureDevice = captureDevice
        self.stillImageBlendFilter = Filter(name: "CILightenBlendMode")
        self.compoundImage = CompoundImage()
        
        if let backCamera = AVCaptureDevice.captureDevice(.Back) {
            let backCameraResolution = backCamera.activeFormat?.highResolutionStillImageDimensions
            self.maxStillImageResolution = CGSize(width: Int(backCameraResolution!.width), height: Int(backCameraResolution!.height))
        } else {
            NSLog("StillImageController init failed - back captureDevice couldn't be found")
            return nil
        }
    }
    
    func compoundStillImageFromImage(ciImage: CIImage, completion: (compoundImage: CompoundImage) -> ()) {
        let normalizedImg = normalizedImage(ciImage)
        addImageToCompoundImage(normalizedImg)
        if compoundImage.completed {
            saveCompoundImage()
        }
        completion(compoundImage: compoundImage)
    }
    
    func reset() {
        stillImageBlendFilter.inputBackgroundImage = nil
        compoundImage = CompoundImage()
    }
    
    private func normalizedImage(ciImage: CIImage) -> CIImage {
        if captureDevice?.position == .Front {
            let flipppedCIImage = ciImage.verticalFlippedImage()
            let scaledFlippedCIImage = flipppedCIImage.scaledToResolution(maxStillImageResolution)
            return scaledFlippedCIImage
        }
        return ciImage
    }
    
    private func addImageToCompoundImage(ciImage: CIImage) {
        guard !compoundImage.completed && captureDevice != nil else { return }
        if let image = compoundImage.image {
            stillImageBlendFilter.inputBackgroundImage = CIImage(CGImage: image)
        }
        stillImageBlendFilter.inputImage = ciImage
        let blendedCGImage = ciContext.createCGImage(stillImageBlendFilter.outputImage!, fromRect:stillImageBlendFilter.outputImage!.extent)
        compoundImage.image = blendedCGImage
        compoundImage.imageOrientation = UIImageOrientation.relationToDeviceOrientaton()
        stillImageBlendFilter.inputImage = nil // ciImage has to be set to nil in order to capture another ciImage
    }
    
    private func saveCompoundImage() {
        guard captureDevice != nil && compoundImage.image != nil && compoundImage.imageOrientation != nil else { return }
        GAHelper.trackCompletePhotocapture()
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
            let rotatedUIImage = UIImage(CGImage: self.compoundImage.image!, scale: 1.0, orientation: self.compoundImage.imageOrientation!)            
            PHAssetCreationRequest.creationRequestForAssetFromImage(rotatedUIImage)
        }) { (success, error) -> Void in
            if (!success) {
                NSLog("could not save image to photo library")
            } else {
                GAHelper.trackPhotoSaved()
                NSLog("image saved to photo library")
            }
        }
    }
    
}