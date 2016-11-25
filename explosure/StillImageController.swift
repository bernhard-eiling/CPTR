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
        guard let backCamera = AVCaptureDevice.captureDevice(.back) else { return nil }
        let backCameraResolution = backCamera.activeFormat?.highResolutionStillImageDimensions
        return CGSize(width: Int(backCameraResolution!.width), height: Int(backCameraResolution!.height))
    }
    private let stillImageBlendFilter: Filter
    
    init() {
        self.ciContext = CIContext(eaglContext: EAGLContext(api: .openGLES2))
        self.stillImageBlendFilter = Filter(name: "CILightenBlendMode")
        self.compoundImage = CompoundImage()
    }
    
    func compoundStillImage(fromCIImage ciImage: CIImage, devicePosition: AVCaptureDevicePosition, completion: @escaping (_ compoundImage: CompoundImage) -> ()) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async(execute: {
            let normalizedImg = self.normalizedCIImage(fromCIImage: ciImage, devicePosition: devicePosition)
            self.add(normalizedImg, toCompoundImage: self.compoundImage)
            if self.compoundImage.completed {
                GAHelper.trackCompletePhotocapture()
                self.finalize(self.compoundImage)
            }
            DispatchQueue.main.async(execute: {
                completion(self.compoundImage)
            })
        })
    }
    
    func reset() {
        stillImageBlendFilter.inputBackgroundImage = nil
        compoundImage = CompoundImage()
    }

    private func normalizedCIImage(fromCIImage ciImage: CIImage, devicePosition: AVCaptureDevicePosition) -> CIImage {
        if devicePosition == .front {
            let flipppedCIImage = ciImage.verticalFlippedImage()
            let scaledFlippedCIImage = flipppedCIImage.scale(toResolution: maxStillImageResolution!)
            return scaledFlippedCIImage
        }
        return ciImage
    }
    
    private func add(_ ciImage: CIImage, toCompoundImage compoundImage: CompoundImage) {
        guard !compoundImage.completed else { return }
        if let image = compoundImage.image {
            stillImageBlendFilter.inputBackgroundImage = CIImage(cgImage: image)
        }
        stillImageBlendFilter.inputImage = ciImage
        let blendedCGImage = ciContext.createCGImage(stillImageBlendFilter.outputImage!, from:stillImageBlendFilter.outputImage!.extent)
        compoundImage.image = blendedCGImage
        compoundImage.imageOrientation = UIImageOrientation.relationToDeviceOrientaton()
        stillImageBlendFilter.inputImage = nil // ciImage has to be set to nil in order to capture another ciImage
    }
    
    private func addJpegUrl(toCompoundImage compoundImage: CompoundImage) {
        let rotatedUIImage = UIImage(cgImage:compoundImage.image!, scale: 1.0, orientation:compoundImage.imageOrientation!)
        let jpegImage = UIImageJPEGRepresentation(rotatedUIImage, 1.0)
        let homePathString = NSTemporaryDirectory() + "/captr.jpeg";
        let homePathUrl = URL(fileURLWithPath: homePathString)
        do {
            try jpegImage!.write(to: homePathUrl, options: .atomic)
        } catch {
            NSLog("could not safe temp image")
        }
        compoundImage.jpegUrl = homePathUrl
    }
    
    private func finalize(_ compoundImage: CompoundImage) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async(execute: {
            self.addJpegUrl(toCompoundImage: self.compoundImage)
            self.save(self.compoundImage)
        })
    }
    
    private func save(_ compoundImage: CompoundImage) {
        guard compoundImage.completed else { return }
        PHPhotoLibrary.requestAuthorization { (status) in
            guard status == .authorized else {
                NSLog("photo permission not given")
                return
            }
            PHPhotoLibrary.shared().performChanges({ () -> Void in
                guard self.compoundImage.completed else { return }
                let rotatedUIImage = UIImage(cgImage: self.compoundImage.image!, scale: 1.0, orientation: self.compoundImage.imageOrientation!)
                PHAssetCreationRequest.creationRequestForAsset(from: rotatedUIImage)
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
