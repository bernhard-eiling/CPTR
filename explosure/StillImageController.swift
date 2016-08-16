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
    
    func compoundStillImage(fromCIImage ciImage: CIImage, devicePosition: AVCaptureDevicePosition, completion: (compoundImage: CompoundImage) -> ()) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), {
            let normalizedImg = self.normalizedCIImage(fromCIImage: ciImage, devicePosition: devicePosition)
            self.add(normalizedImg, toCompoundImage: self.compoundImage)
            if self.compoundImage.completed {
                GAHelper.trackCompletePhotocapture()
                self.finalize(self.compoundImage)
            }
            dispatch_async(dispatch_get_main_queue(), {
                completion(compoundImage: self.compoundImage)
            })
        })
    }
    
    func reset() {
        stillImageBlendFilter.inputBackgroundImage = nil
        compoundImage = CompoundImage()
    }

    private func normalizedCIImage(fromCIImage ciImage: CIImage, devicePosition: AVCaptureDevicePosition) -> CIImage {
        if devicePosition == .Front {
            let flipppedCIImage = ciImage.verticalFlippedImage()
            let scaledFlippedCIImage = flipppedCIImage.scaledToResolution(maxStillImageResolution!)
            return scaledFlippedCIImage
        }
        return ciImage
    }
    
    private func add(ciImage: CIImage, toCompoundImage compoundImage: CompoundImage) {
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
    
    private func addJpegUrl(toCompoundImage compoundImage: CompoundImage) {
        let rotatedUIImage = UIImage(CGImage:compoundImage.image!, scale: 1.0, orientation:compoundImage.imageOrientation!)
        let jpegImage = UIImageJPEGRepresentation(rotatedUIImage, 1.0)
        let homePathString = NSTemporaryDirectory() + "/captr.jpeg";
        let homePathUrl = NSURL(fileURLWithPath: homePathString)
        do {
            try jpegImage!.writeToURL(homePathUrl, options: .DataWritingAtomic)
        } catch {
            NSLog("could not safe temp image")
        }
        compoundImage.jpegUrl = homePathUrl
    }
    
    private func finalize(compoundImage: CompoundImage) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), {
            self.addJpegUrl(toCompoundImage: self.compoundImage)
            self.save(self.compoundImage)
        })
    }
    
    private func save(compoundImage: CompoundImage) {
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
