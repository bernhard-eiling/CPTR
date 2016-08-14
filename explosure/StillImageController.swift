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
    
    private(set) var compoundImage: CompoundImage
    
    private let ciContext: CIContext
    private var maxStillImageResolution: CGSize? {
        guard let backCamera = AVCaptureDevice.captureDevice(.Back) else { return nil }
        let backCameraResolution = backCamera.activeFormat?.highResolutionStillImageDimensions
        return CGSize(width: Int(backCameraResolution!.width), height: Int(backCameraResolution!.height))
    }
    private let stillImageBlendFilter: Filter
    
    init() {
        
        self.ciContext = CIContext(EAGLContext: EAGLContext(API: .OpenGLES2))
        self.stillImageBlendFilter = Filter(name: "CILightenBlendMode")
        self.compoundImage = CompoundImage()
    }
    
    func compoundStillImageFromImage(ciImage: CIImage, devicePosition: AVCaptureDevicePosition, completion: (compoundImage: CompoundImage) -> ()) {
        let normalizedImg = normalizedImageFromImage(ciImage, devicePosition: devicePosition)
        addImageToCompoundImage(normalizedImg)
        if compoundImage.completed {
            GAHelper.trackCompletePhotocapture()
            saveCompoundImage()
        }
        completion(compoundImage: compoundImage)
    }
    
    func reset() {
        stillImageBlendFilter.inputBackgroundImage = nil
        compoundImage = CompoundImage()
    }
    
    private func normalizedImageFromImage(ciImage: CIImage, devicePosition: AVCaptureDevicePosition) -> CIImage {
        if devicePosition == .Front {
            let flipppedCIImage = ciImage.verticalFlippedImage()
            let scaledFlippedCIImage = flipppedCIImage.scaledToResolution(maxStillImageResolution!)
            return scaledFlippedCIImage
        }
        return ciImage
    }
    
    private func addImageToCompoundImage(ciImage: CIImage) {
        guard !compoundImage.completed else { return }
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
        guard compoundImage.completed else { return }
        PHPhotoLibrary.requestAuthorization { (status) in
            guard status == .Authorized else {
                NSLog("photo permission not given")
                return
            }
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
                guard self.compoundImage.completed else { return }
                let rotatedUIImage = UIImage(CGImage: self.compoundImage.image!, scale: 1.0, orientation: self.compoundImage.imageOrientation!)
                PHAssetCreationRequest.creationRequestForAssetFromImage(rotatedUIImage)
            }) { (success, error) -> Void in
                if !success {
                    NSLog("could not save image to photo library")
                    return
                }
                GAHelper.trackPhotoSaved()
                NSLog("image saved to photo library")
            }
        }
    }
    
}
