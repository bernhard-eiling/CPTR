//
//  CameraController.swift
//  explosure
//
//  Created by Bernhard Eiling on 12.10.15.
//  Copyright © 2015 bernhardeiling. All rights reserved.
//

import Foundation
import AVFoundation
import GLKit

class CameraController : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, PhotoControllerDelegate {
    
    var glView: GLKView? {
        didSet {
            if let glView = glView {
                glView.context = glContext
                glView.enableSetNeedsDisplay = false
            } else {
                NSLog("wait for nib to init")
            }
        }
    }
    
    var savedPhoto: UIImage?
    private let photoController: PhotoController
    private var stillImageOutput: AVCaptureStillImageOutput?
    private let glContext: EAGLContext
    private let ciContext: CIContext
    private let captureSession: AVCaptureSession
    private var blendFilter: CIFilter
    private var captureDevice: AVCaptureDevice?
    
    private var blendedPhoto: CGImage?
    
    override init() {
        glContext = EAGLContext(API: .OpenGLES2)
        ciContext = CIContext(EAGLContext: glContext)
        blendFilter = CIFilter(name: "CISoftLightBlendMode")!
        captureSession = AVCaptureSession()
        photoController = PhotoController()
        super.init()
    }
    
    func setupCaptureSessionWithDelegate(delegate: PhotoControllerDelegate) {
        photoController.cameraControllerDelegate = self
        photoController.cameraViewControllerDelegate = delegate
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        addCaptureDeviceInput()
        addStillImageDataOutput()
        setStillImageOrientation(.Portrait)
        if let videoDataOutput = videoDataOutput() {
            setVideoOrientation(.Portrait, videoDataOutput: videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL))
        }
        let sessionQueue = dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)
        dispatch_async(sessionQueue) { () -> Void in
            self.captureSession.startRunning()
        }
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if glContext != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(glContext)
        }
        drawVideoWithSampleBuffer(sampleBuffer)
    }
    
    func captureImage() {
        if photoController.isSavingPhoto {
            NSLog("photo is still being saved")
            return
        }
        photoController.isSavingPhoto = true
        let sessionQueue = dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)
        dispatch_async(sessionQueue) { () -> Void in
            if let stillImageOutput = self.stillImageOutput {
                let stillImageConnection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
                stillImageOutput.captureStillImageAsynchronouslyFromConnection(stillImageConnection, completionHandler: { (imageDataSampleBuffer: CMSampleBuffer?, error: NSError?) -> Void in
                    if let ciImage = self.ciImageFromImageBuffer(imageDataSampleBuffer) {
                        self.photoController.addPhoto(self.ciContext.createCGImage(ciImage, fromRect: ciImage.extent))
                    }
                })
            }
        }
    }
    
    func ciImageFromImageBuffer(imageSampleBuffer: CMSampleBuffer?) -> CIImage? {
        if let sampleBuffer = imageSampleBuffer {
            if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let ciImage = CIImage(CVPixelBuffer: imageBuffer)
                return ciImage
            }
        }
        NSLog("Could not convert image buffer to CIImage")
        return nil
    }
    
    func drawVideoWithSampleBuffer(sampleBuffer: CMSampleBuffer!) {
        if self.savedPhoto != nil {
            return
        }
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            blendFilter.setValue(CIImage(CVPixelBuffer: imageBuffer), forKey: "inputImage")
            if blendFilter.outputImage != nil && glView != nil {
                glView!.bindDrawable()
                let drawRect = CGRectMake(0, 0, blendFilter.outputImage!.extent.width, blendFilter.outputImage!.extent.height)
                ciContext.drawImage(blendFilter.outputImage!, inRect: drawRect, fromRect: blendFilter.outputImage!.extent)
                glView!.display()
            }
        }
    }
    
    func photoSavedToPhotoLibrary(savedPhoto: UIImage) {
        self.savedPhoto = savedPhoto
    }
    
    func blendedPhotoDidChange(blendedPhoto: CGImage?) {
        if let backgroundPhoto = blendedPhoto {
            let drawSize = CGSize(width: 640.0, height: 852.0)
            UIGraphicsBeginImageContext(drawSize)
            let context: CGContext? = UIGraphicsGetCurrentContext()
            CGContextScaleCTM(context, -1.0, 1.0)
            CGContextRotateCTM(context, CGFloat(M_PI_2))
            CGContextDrawImage(context, CGRect(origin: CGPointZero, size: CGSize(width: 852.0, height: 640.0)), backgroundPhoto)
            let ciImage = CIImage(CGImage: CGBitmapContextCreateImage(context)!)
            self.blendFilter.setValue(ciImage, forKey: "inputBackgroundImage")
            UIGraphicsEndImageContext();
        } else {
            resetCameraView()
        }
    }
    
    func focusCaptureDeviceWithPoint(focusPoint: CGPoint) {
        let normalizedFocusPoint = CGPoint(x: focusPoint.y / glView!.frame.size.height, y: 1.0 - (focusPoint.x / glView!.frame.size.width)) // coordinates switch is necessarry due to 90 degree rotation of camera
        if let captureDevice = self.captureDevice {
        do {
            try captureDevice.lockForConfiguration()
        } catch {
            NSLog("focus capture device failed")
            return
        }
        if captureDevice.focusPointOfInterestSupported {
            captureDevice.focusPointOfInterest = normalizedFocusPoint
            captureDevice.focusMode = .AutoFocus
        }
        captureDevice.unlockForConfiguration()
        }
    }
    
    func resetCameraView() {
        self.blendFilter.setValue(nil, forKey: "inputBackgroundImage")
    }

    func addCaptureDeviceInput() {
        var captureDeviceInput : AVCaptureDeviceInput
        do {
            captureDevice = backCameraDevice()
            if self.captureDevice != nil {
                captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
                if captureSession.canAddInput(captureDeviceInput) {
                    captureSession.addInput(captureDeviceInput)
                }
            }
        } catch {
            NSLog("capture device could not be added to session");
        }
    }
    
    func videoDataOutput() -> AVCaptureVideoDataOutput? {
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt: kCVPixelFormatType_32BGRA)]
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            return videoDataOutput
        }
        NSLog("could not add VideoDataOutput to session")
        return nil
    }
    
    func addStillImageDataOutput() {
        stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput!.outputSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
            return
        }
        NSLog("could not add StillImageDataOutput to session")
    }
    
    func setVideoOrientation(orientation: AVCaptureVideoOrientation, videoDataOutput: AVCaptureVideoDataOutput) {
        let videoOutputConnection = videoDataOutput.connectionWithMediaType(AVMediaTypeVideo)
        if videoOutputConnection.supportsVideoOrientation {
            videoOutputConnection.videoOrientation = orientation
        }
    }
    
    func setStillImageOrientation(orientation: AVCaptureVideoOrientation) {
        let stillImageOutputConenction = stillImageOutput!.connectionWithMediaType(AVMediaTypeVideo)
        if stillImageOutputConenction.supportsVideoOrientation {
            stillImageOutputConenction.videoOrientation = orientation
        }
    }
    
    func backCameraDevice() -> AVCaptureDevice? {
        let captureDevices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for captureDevice in captureDevices as! [AVCaptureDevice] {
            if captureDevice.position == .Back {
                return captureDevice;
            }
        }
        return nil;
    }
    
}