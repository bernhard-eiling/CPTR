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

    private var isSavingPhoto: Bool
    private let photoCapaciy = 2
    private var photoCounter = 0
    
    var glViewControllerDelegate: GLViewControllerDelegate?
    
    @IBOutlet var glView: GLKView!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        blendFilter = CIFilter(name: "CISoftLightBlendMode")!
        glContext = EAGLContext(API: .OpenGLES2)
        ciContext = CIContext(EAGLContext: glContext)
        captureSession = AVCaptureSession()
        isSavingPhoto = false
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init(coder aCoder: NSCoder) {
        fatalError("NSCoding not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        addCaptureDeviceInput()
        addStillImageDataOutput()
        setStillImageOrientation(.Portrait)
        
        glView.context = glContext
        glView.enableSetNeedsDisplay = false
        
        if let videoDataOutput = videoDataOutput() {
            setVideoOrientation(.Portrait, videoDataOutput: videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL))
        }
        dispatch_async(dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)) { () -> Void in
            self.captureSession.startRunning()
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
    
    private func drawVideoWithSampleBuffer(sampleBuffer: CMSampleBuffer!) {
        if savedPhoto != nil {
            return
        }
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            blendFilter.setValue(CIImage(CVPixelBuffer: imageBuffer), forKey: "inputImage")
            if blendFilter.outputImage != nil && view != nil {
                glView.bindDrawable()
                let drawRect = CGRectMake(0, 0, blendFilter.outputImage!.extent.width, blendFilter.outputImage!.extent.height)
                ciContext.drawImage(blendFilter.outputImage!, inRect: drawRect, fromRect: blendFilter.outputImage!.extent)
                glView.display()
            }
        }
    }

    func setFilterBackgroundImage(blendedPhoto: CGImage?) {
        if let backgroundPhoto = blendedPhoto {
            let ciImage = CIImage(CGImage: backgroundPhoto)
            self.blendFilter.setValue(ciImage, forKey: "inputBackgroundImage")
        } else {
            resetCameraView()
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
                        let cgImageSize = CGSize(width: CGImageGetWidth(cgImage), height: CGImageGetHeight(cgImage))
                        let rotatedGgImage = self.rotateCGImage90Degrees(cgImage, toSize: cgImageSize)
                        self.addPhoto(rotatedGgImage)
                    }
                })
            }
        }
    }
    
    func addPhoto(photo: CGImage) {
        if photoCounter >= photoCapaciy {
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
            
            self.setFilterBackgroundImage(self.blendedPhoto)
            
            if (self.photoCounter >= self.photoCapaciy) {
                self.saveImageToPhotoLibrary()
            }
        }
    }
    
    private func saveImageToPhotoLibrary() {
        self.glViewControllerDelegate?.photoSavedToPhotoLibrary(UIImage(CGImage: self.blendedPhoto!))
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
            let rotatedUIImage = self.rotatedImageAccordingToDeviceOrientation(self.blendedPhoto!)
            PHAssetCreationRequest.creationRequestForAssetFromImage(rotatedUIImage)
            }) { (success, error) -> Void in
                self.isSavingPhoto = false
                if (!success) {
                    NSLog("could not save image to photo library")
                } else {
                    self.savedPhoto = self.blendedPhoto
                    self.photoCounter = 0
                    self.blendedPhoto = nil
                    NSLog("image saved to photo library")
                }
        }
        
    }
    
    
    // HELPER
    
    func rotateCGImage90Degrees(cgImage: CGImage, toSize size:CGSize) -> CGImage {
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
    
    func sizeOfCGImage(image: CGImage) -> CGSize {
        return CGSize(width: CGImageGetWidth(image), height: CGImageGetHeight(image))
    }
    
    func rectOfCGImage(image: CGImage) -> CGRect {
        return CGRect(origin: CGPointZero, size: sizeOfCGImage(image))
    }
    
    func resetCameraView() {
        self.blendFilter.setValue(nil, forKey: "inputBackgroundImage")
    }
    
    
    // VIDEO DRAWING
    
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
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if glContext != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(glContext)
        }
        drawVideoWithSampleBuffer(sampleBuffer)
    }
    
    
    
    // AVCapture SETUP
    
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
