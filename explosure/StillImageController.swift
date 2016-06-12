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
    
    private let ciContext: CIContext
    private let stillImageOutput: AVCaptureStillImageOutput
    private let captureDevice: AVCaptureDevice
    private let maxStillImageResolution: CGSize
    private var compoundImage: CompoundImage?
    private let stillImageBlendFilter: Filter
    
    init?(ciContext: CIContext, stillImageOutput: AVCaptureStillImageOutput, captureDevice: AVCaptureDevice) {
        self.ciContext = ciContext
        self.stillImageOutput = stillImageOutput
        self.captureDevice = captureDevice
        self.stillImageBlendFilter = Filter(name: "CILightenBlendMode")
        
        if let backCamera = AVCaptureDevice.captureDevice(.Back) {
            let backCameraResolution = backCamera.activeFormat?.highResolutionStillImageDimensions
            self.maxStillImageResolution = CGSize(width: Int(backCameraResolution!.width), height: Int(backCameraResolution!.height))
        } else {
            NSLog("back captureDevice couldn't be found")
            return nil
        }
    }
    
    func captureCompoundStillImage() {
        
        
        // capture in GLViewController legen ? self.stillImageOutput müsste nicht mehr übergeben werden
        dispatch_async(dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)) { () -> Void in
            let stillImageConnection = self.stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
            self.stillImageOutput.captureStillImageAsynchronouslyFromConnection(stillImageConnection, completionHandler: { (imageDataSampleBuffer: CMSampleBuffer?, error: NSError?) -> Void in
                if let ciImage = self.ciImageFromImageBuffer(imageDataSampleBuffer) {
                    
                    // dispatching back ?
                    self.createCompoundImage(ciImage)
                }
            })
            
        }
    }
    
    private func createCompoundImage(ciImage: CIImage) {
        var capturedImage = ciImage
        if captureDevice.position == .Front {
            let flipppedCIImage = ciImage.verticalFlippedImage()
            capturedImage = flipppedCIImage.scaledToResolution(maxStillImageResolution)
        }
        compoundImage(capturedImage)
        self.saveBlendedImageIfPossible()
    }
    
    private func compoundImage(ciImage: CIImage) {
        if compoundImage == nil { // first photo cannot blend with other photo
            let cgImage = ciContext.createCGImage(ciImage, fromRect: ciImage.extent)
            compoundImage = CompoundImage(image: cgImage, imageOrientation: self.imageOrientation())
        } else {
            self.stillImageBlendFilter.inputBackgroundImage = CIImage(CGImage: self.compoundImage!.image)
            self.stillImageBlendFilter.inputImage = ciImage
            
            let blendedCGImage = self.ciContext.createCGImage(self.stillImageBlendFilter.outputImage!, fromRect: self.stillImageBlendFilter.outputImage!.extent)
            compoundImage!.image = blendedCGImage
            compoundImage!.imageOrientation = self.imageOrientation()
        }
        // setting BG video filter for front facing camera broken
        //            self.setFilterBackgroundPhoto(self.blendedPhoto!.image)
    }
    
    private func saveBlendedImageIfPossible() {
        GAHelper.trackCompletePhotocapture()
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
            let rotatedUIImage = UIImage(CGImage: self.compoundImage!.image, scale: 1.0, orientation: self.imageOrientation())
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
    
    private func ciImageFromImageBuffer(imageSampleBuffer: CMSampleBuffer?) -> CIImage? {
        if let sampleBuffer = imageSampleBuffer {
            if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let ciImage = CIImage(CVPixelBuffer: imageBuffer)
                return ciImage
            }
        }
        NSLog("Could not convert image buffer to CIImage")
        return nil
    }
    
    // move to extension ?
    private func imageOrientation() -> UIImageOrientation {
        switch self.captureDevice.position {
        case .Back: do {
            switch UIDevice.currentDevice().orientation {
            case .Portrait:
                return .Right
            case .LandscapeLeft:
                return .Up
            case .LandscapeRight:
                return .Down
            case .PortraitUpsideDown:
                return .Left
            default:
                return .Left
            }
            }
            
        case .Front: do {
            switch UIDevice.currentDevice().orientation {
            case .Portrait:
                return .Left
            case .LandscapeLeft:
                return .Down
            case .LandscapeRight:
                return .Up
            case .PortraitUpsideDown:
                return .Right
            default:
                return .Right
            }
            }
        default:
            return .Left
        }
        return .Left
    }
    
}