//
//  GLViewController.swift
//  explosure
//
//  Created by Bernhard Eiling on 15.11.15.
//  Copyright © 2015 bernhardeiling. All rights reserved.
//

import UIKit
import AVFoundation
import GLKit
import Photos

protocol GLViewControllerDelegate {
    func photoSavedToPhotoLibrary(savedPhoto: UIImage)
}

class GLViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var savedPhoto: CGImage?
    
    private var stillImageOutput: AVCaptureStillImageOutput?
    private var blendFilter: CIFilter
    private let glContext: EAGLContext
    private let ciContext: CIContext
    private let captureSession: AVCaptureSession
    private var captureDevice: AVCaptureDevice?
    private var blendedPhoto: CGImage?

    private let photoCapacity = 2.0
    private var photoCounter = 0.0
    
    var glViewControllerDelegate: GLViewControllerDelegate?
    
    @IBOutlet var glView: GLKView!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        self.blendFilter = CIFilter(name: "CISoftLightBlendMode")!
        self.glContext = EAGLContext(API: .OpenGLES2)
        self.ciContext = CIContext(EAGLContext: self.glContext)
        self.captureSession = AVCaptureSession()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init(coder aCoder: NSCoder) {
        fatalError("NSCoding not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        self.addCaptureDeviceInput()
        self.addStillImageDataOutput()
        self.setStillImageOrientation(.Portrait)
        
        self.glView.context = self.glContext
        self.glView.enableSetNeedsDisplay = false
        
        if let videoDataOutput = videoDataOutput() {
            self.setVideoOrientation(.Portrait, videoDataOutput: videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL))
        }
        dispatch_async(dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)) { () -> Void in
            self.captureSession.startRunning()
        }
    }
    
    func focusCaptureDeviceWithPoint(focusPoint: CGPoint) {
        let normalizedFocusPoint = CGPoint(x: focusPoint.y / self.glView!.frame.size.height, y: 1.0 - (focusPoint.x / self.glView!.frame.size.width)) // coordinates switch is necessarry due to 90 degree rotation of camera
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
    
    private func drawVideoWithSampleBuffer(sampleBuffer: CMSampleBuffer!) {
        if self.savedPhoto != nil {
            return
        }
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            self.blendFilter.setValue(CIImage(CVPixelBuffer: imageBuffer), forKey: "inputImage")
            if self.blendFilter.outputImage != nil && view != nil {
                self.glView.bindDrawable()
                let drawRect = CGRectMake(0, 0, self.blendFilter.outputImage!.extent.width, self.blendFilter.outputImage!.extent.height)
                self.ciContext.drawImage(self.blendFilter.outputImage!, inRect: drawRect, fromRect: self.blendFilter.outputImage!.extent)
                self.glView.display()
            }
        }
    }
    
    
    // STILL IMAGE CAPTURE
    func captureImage() {
        dispatch_async(dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)) { () -> Void in
            if let stillImageOutput = self.stillImageOutput {
                let stillImageConnection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
                stillImageOutput.captureStillImageAsynchronouslyFromConnection(stillImageConnection, completionHandler: { (imageDataSampleBuffer: CMSampleBuffer?, error: NSError?) -> Void in
                    if let ciImage = self.ciImageFromImageBuffer(imageDataSampleBuffer) {
                        let cgImage = self.ciContext.createCGImage(ciImage, fromRect: ciImage.extent)
                        self.blendPhoto(cgImage)
                    }
                })
            }
        }
    }

    private func blendPhoto(photo: CGImage) {
        if self.photoCounter >= self.photoCapacity {
            NSLog("photo capacity reached")
            return
        }
        self.photoCounter++
        NSLog ("photo count: %i", self.photoCounter)
        
        let sessionQueue = dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)
        dispatch_async(sessionQueue) { () -> Void in
            UIGraphicsBeginImageContext(self.sizeOfCGImage(photo))
            let context: CGContext? = UIGraphicsGetCurrentContext()
            CGContextScaleCTM(context, 1.0, -1.0) // flip
            CGContextTranslateCTM(context, 0.0, -CGFloat(CGImageGetHeight(photo)))
            CGContextDrawImage(context, self.rectOfCGImage(photo), self.blendedPhoto)
            CGContextSetBlendMode(context, .Normal)
            CGContextSetAlpha(context, 0.5)
            CGContextDrawImage(context, self.rectOfCGImage(photo), photo)
            self.blendedPhoto = CGBitmapContextCreateImage(context)
            UIGraphicsEndImageContext();
            
            self.saveImageToPhotoLibrary(self.blendedPhoto)
            
            
//            self.setFilterBackgroundImage(self.blendedPhoto)
//            if (self.photoCounter >= self.photoCapacity) {
//                self.saveImageToPhotoLibrary(self.blendedPhoto)
//            }
        }
    }
    
    private func setFilterBackgroundImage(backgroundPhoto: CGImage?) {
        if let backgroundPhoto = backgroundPhoto {
            let ciImage = CIImage(CGImage: backgroundPhoto)
            self.blendFilter.setValue(ciImage, forKey: "inputBackgroundImage")
        } else {
            self.resetCameraView()
        }
    }
    
    private func saveImageToPhotoLibrary(photo: CGImage?) {
        self.glViewControllerDelegate?.photoSavedToPhotoLibrary(UIImage(CGImage: photo!))
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
            let rotatedUIImage = UIImage(CGImage: photo!, scale: 1.0, orientation: self.imageOrientationAccordingToDeviceOrientation())
            PHAssetCreationRequest.creationRequestForAssetFromImage(rotatedUIImage)
            }) { (success, error) -> Void in
                if (!success) {
                    NSLog("could not save image to photo library")
                } else {
//                    self.savedPhoto = photo
//                    self.photoCounter = 0
//                    self.blendedPhoto = nil
                    NSLog("image saved to photo library")
                }
        }
    }
    
    
    // HELPER
    
    // move this to extension of CGImage
    private func rotateCGImage90Degrees(cgImage: CGImage, toSize size:CGSize) -> CGImage {
        UIGraphicsBeginImageContext(CGSize(width: size.height , height: size.width))
        let context: CGContext? = UIGraphicsGetCurrentContext()
        CGContextTranslateCTM(context, size.height / 2, size.width / 2)
        CGContextRotateCTM(context, CGFloat(M_PI_2))
        CGContextScaleCTM(context, 1.0, -1.0)
        CGContextTranslateCTM(context, -size.width / 2, -size.height / 2)
        CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), cgImage)
        UIGraphicsEndImageContext();
        return CGBitmapContextCreateImage(context!)!
    }
    
    private func imageOrientationAccordingToDeviceOrientation() -> UIImageOrientation {
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
                return .Right
        }
    }
    
    private func sizeOfCGImage(image: CGImage) -> CGSize {
        return CGSize(width: CGImageGetWidth(image), height: CGImageGetHeight(image))
    }
    
    private func rectOfCGImage(image: CGImage) -> CGRect {
        return CGRect(origin: CGPointZero, size: self.sizeOfCGImage(image))
    }
    
    private func resetCameraView() {
        self.blendFilter.setValue(nil, forKey: "inputBackgroundImage")
    }
    
    
    // VIDEO DRAWING
    
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
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if self.glContext != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(self.glContext)
        }
        drawVideoWithSampleBuffer(sampleBuffer)
    }
    
    
    
    // AVCapture SETUP
    
    private func addCaptureDeviceInput() {
        var captureDeviceInput : AVCaptureDeviceInput
        do {
            self.captureDevice = self.backCameraDevice()
            if self.captureDevice != nil {
                captureDeviceInput = try AVCaptureDeviceInput(device: self.captureDevice)
                if self.captureSession.canAddInput(captureDeviceInput) {
                    self.captureSession.addInput(captureDeviceInput)
                }
            }
        } catch {
            NSLog("capture device could not be added to session");
        }
    }
    
    private func videoDataOutput() -> AVCaptureVideoDataOutput? {
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt: kCVPixelFormatType_32BGRA)]
        if self.captureSession.canAddOutput(videoDataOutput) {
            self.captureSession.addOutput(videoDataOutput)
            return videoDataOutput
        }
        NSLog("could not add VideoDataOutput to session")
        return nil
    }
    
    private func addStillImageDataOutput() {
        self.stillImageOutput = AVCaptureStillImageOutput()
        self.stillImageOutput!.outputSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        if self.captureSession.canAddOutput(self.stillImageOutput) {
            self.captureSession.addOutput(self.stillImageOutput)
            return
        }
        NSLog("could not add StillImageDataOutput to session")
    }
    
    private func setVideoOrientation(orientation: AVCaptureVideoOrientation, videoDataOutput: AVCaptureVideoDataOutput) {
        let videoOutputConnection = videoDataOutput.connectionWithMediaType(AVMediaTypeVideo)
        if videoOutputConnection.supportsVideoOrientation {
            videoOutputConnection.videoOrientation = orientation
        }
    }
    
    private func setStillImageOrientation(orientation: AVCaptureVideoOrientation) {
        let stillImageOutputConenction = self.stillImageOutput!.connectionWithMediaType(AVMediaTypeVideo)
        if stillImageOutputConenction.supportsVideoOrientation {
            stillImageOutputConenction.videoOrientation = orientation
        }
    }
    
    private func backCameraDevice() -> AVCaptureDevice? {
        let captureDevices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for captureDevice in captureDevices as! [AVCaptureDevice] {
            if captureDevice.position == .Back {
                return captureDevice;
            }
        }
        return nil;
    }

}
