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
    
    var blendedPhoto: BlendedPhoto?
    
    private var stillImageOutput: AVCaptureStillImageOutput?
    private let glContext: EAGLContext
    private let ciContext: CIContext
    private let captureSession: AVCaptureSession
    private var captureDevice: AVCaptureDevice?
    private var currentCaptureDeviceInput: AVCaptureDeviceInput?
    private var currentvideoDataOutput: AVCaptureVideoDataOutput?
    private var maxStillImageResolution: CGSize?
    
    @IBOutlet weak var cameraAuthDeniedLabel: UILabel!
    
    private let photoCapacity = 2
    private var photoCounter = 0
    private var videoBlendFilter: Filter
    private var stillImageBlendFilter: Filter
    private let filterManager: FilterManager
    
    var glViewControllerDelegate: GLViewControllerDelegate?
    
    @IBOutlet var glView: GLKView!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        self.filterManager = FilterManager()
        self.videoBlendFilter = Filter(name: self.filterManager.filterNames[self.filterManager.currentIndex])
        self.stillImageBlendFilter = Filter(name: self.filterManager.filterNames[self.filterManager.currentIndex])
        self.filterManager.filters = [self.videoBlendFilter, self.stillImageBlendFilter]
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
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplicationDidBecomeActiveNotification, object: nil)
        self.authorizeCamera()
    }
    
    func applicationDidBecomeActive() {
        self.authorizeCamera()
    }
    
    private func authorizeCamera() {
        let authorizationStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        switch authorizationStatus {
        case .NotDetermined:
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo,
                completionHandler: { (granted:Bool) -> Void in
                    if granted {
                        self.cameraAuthDeniedLabel.hidden = true
                        self.setupCamera()
                    }
                    else {
                        self.cameraAuthDeniedLabel.hidden = false
                        NSLog("camera authorization denied")
                    }
            })
        case .Authorized:
            self.cameraAuthDeniedLabel.hidden = true
            self.setupCamera()
        case .Denied, .Restricted:
            self.cameraAuthDeniedLabel.hidden = false
            NSLog("camera authorization denied")
        }
    }
    
    private func setupCamera() {
        if self.captureDevice != nil {
            return
        }
        self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        self.addCaptureDeviceInputFromDevicePosition(.Back)
        self.addStillImageDataOutput()
        
        self.setStillImageOrientation(.Portrait)
        
        self.glView.context = self.glContext
        self.glView.enableSetNeedsDisplay = false
        
        let stillImageDimensions = self.captureDevice?.activeFormat?.highResolutionStillImageDimensions
        self.maxStillImageResolution = CGSize(width: Int(stillImageDimensions!.width), height: Int(stillImageDimensions!.height)) // max resolution of front camera
        
        self.currentvideoDataOutput = self.videoDataOutput()
        if let videoDataOutput = self.currentvideoDataOutput {
            self.setVideoOrientation(.Portrait, videoDataOutput: videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL))
        }
        dispatch_async(dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)) { () -> Void in
            self.captureSession.startRunning()
        }
    }
    
    @IBAction func filterSwipedLeft(sender: UISwipeGestureRecognizer) {
        self.filterManager.last()
    }
    
    @IBAction func filterSwipedRight(sender: UISwipeGestureRecognizer) {
        self.filterManager.next()
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
        if self.capacityReached() {
            return
        }
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            self.videoBlendFilter.inputImage = CIImage(CVPixelBuffer: imageBuffer)
            if self.videoBlendFilter.outputImage != nil && view != nil {
                self.glView.bindDrawable()
                let flippedCIImage = self.flippedCIImageIfFrontCamera(self.videoBlendFilter.outputImage!)
                self.ciContext.drawImage(flippedCIImage, inRect: flippedCIImage.extent, fromRect: flippedCIImage.extent)
                self.glView.display()
            }
        }
    }
    
    func toggleCamera() {
        if let captureDevice = self.captureDevice {
            switch captureDevice.position {
            case .Back:
                self.addCaptureDeviceInputFromDevicePosition(.Front)
            case .Front:
                self.addCaptureDeviceInputFromDevicePosition(.Back)
            default:
                self.addCaptureDeviceInputFromDevicePosition(.Front)
            }
        }
        if let videoDataOutput = self.currentvideoDataOutput {
            self.setVideoOrientation(.Portrait, videoDataOutput: videoDataOutput)
        }
    }
    
    
    // STILL IMAGE CAPTURE
    func captureImage() {
        if self.capacityReached() {
            self.resetBlender()
            return
        }
        dispatch_async(dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)) { () -> Void in
            if let stillImageOutput = self.stillImageOutput {
                let stillImageConnection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
                stillImageOutput.captureStillImageAsynchronouslyFromConnection(stillImageConnection, completionHandler: { (imageDataSampleBuffer: CMSampleBuffer?, error: NSError?) -> Void in
                    if let ciImage = self.ciImageFromImageBuffer(imageDataSampleBuffer) {
                        let normalizedCIImage = self.normalizeCIImage(ciImage)
                        self.blendCIImagePhoto(normalizedCIImage)
                    }
                })
            }
        }
    }
    
    private func normalizeCIImage(ciImage: CIImage) -> CIImage{
        return self.scaledCIImageIfNecessary(self.flippedCIImageIfFrontCamera(ciImage))
    }
    
    private func blendCIImagePhoto(photo: CIImage) {
        if self.capacityReached() {
            NSLog("photo capacity reached")
            return
        }
        self.photoCounter += 1
        NSLog ("photo count: %i", self.photoCounter)
        
        let sessionQueue = dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)
        dispatch_async(sessionQueue) { () -> Void in
            let cgPhoto = self.ciContext.createCGImage(photo, fromRect: photo.extent)
            if self.blendedPhoto == nil { // first photo cannot blend with other photo
                self.blendedPhoto = BlendedPhoto(image: cgPhoto, imageOrientation: self.imageOrientation())
            } else {
                self.stillImageBlendFilter.inputBackgroundImage = CIImage(CGImage: self.blendedPhoto!.image)
                self.stillImageBlendFilter.inputImage = photo
                
                let blendedCGImage = self.ciContext.createCGImage(self.stillImageBlendFilter.outputImage!, fromRect: self.stillImageBlendFilter.outputImage!.extent)
                self.blendedPhoto!.image = blendedCGImage
                self.blendedPhoto!.imageOrientation = self.imageOrientation()
            }
            self.saveBlendedImageIfPossible()
            self.setFilterBackgroundPhoto(self.blendedPhoto!.image)
        }
    }
    
    private func setFilterBackgroundPhoto(photo: CGImage) {
        let pixelSize = CGSize(width: self.glView.frame.width * self.glView.contentScaleFactor, height: self.glView.frame.height * self.glView.contentScaleFactor)
        let scaledCGimage: CGImage
        if self.captureDevice?.position == .Back {
            scaledCGimage = photo.rotate90Degrees(toSize: pixelSize, degrees: M_PI_2)
        } else {
            scaledCGimage = photo.rotate90Degrees(toSize: pixelSize, degrees: -M_PI_2)
        }
        let ciImage = CIImage(CGImage: scaledCGimage)
        self.videoBlendFilter.inputBackgroundImage = self.flippedCIImageIfFrontCamera(ciImage)
    }
    
    private func saveBlendedImageIfPossible() {
        if !self.capacityReached() {
            return
        }
        GAHelper.trackCompletePhotocapture()
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
            let rotatedUIImage = UIImage(CGImage: self.blendedPhoto!.image, scale: 1.0, orientation: self.imageOrientation())
            PHAssetCreationRequest.creationRequestForAssetFromImage(rotatedUIImage)
            }) { (success, error) -> Void in
                if (!success) {
                    NSLog("could not save image to photo library")
                } else {
                    GAHelper.trackPhotoSaved()
                    self.glViewControllerDelegate?.photoSavedToPhotoLibrary(UIImage(CGImage: self.blendedPhoto!.image))
                    NSLog("image saved to photo library")
                }
        }
    }
    
    
    // HELPER
    
    private func imageOrientation() -> UIImageOrientation {
        if let cameraPosition = self.captureDevice?.position {
            switch cameraPosition {
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
        }
        return .Left
    }
    
    private func scaledCIImageIfNecessary(ciImage: CIImage) -> CIImage {
        if ciImage.extent.size == self.maxStillImageResolution {
            return ciImage;
        }
        let xScale = self.maxStillImageResolution!.width / ciImage.extent.size.width
        let yScale = self.maxStillImageResolution!.height / ciImage.extent.size.height
        let transformScale = CGAffineTransformMakeScale(xScale, yScale)
        return ciImage.imageByApplyingTransform(transformScale)
    }
    
    private func flippedCIImageIfFrontCamera(ciImage: CIImage) -> CIImage {
        if let captureDevice = self.captureDevice {
            switch captureDevice.position {
            case .Back:
                return ciImage
            case .Front:
                let transformTranslate = CGAffineTransformMakeTranslation(self.glView.frame.width * self.glView.contentScaleFactor, 0)
                let transformScale = CGAffineTransformMakeScale(-1.0, 1.0)
                return ciImage.imageByApplyingTransform(CGAffineTransformConcat(transformScale, transformTranslate))
            default:
                return ciImage
            }
        }
        return ciImage;
    }
    
    private func capacityReached() -> Bool {
        return self.photoCounter >= self.photoCapacity
    }
    
    private func resetBlender() {
        self.photoCounter = 0
        self.blendedPhoto = nil
        self.videoBlendFilter.inputBackgroundImage = nil
        self.stillImageBlendFilter.inputBackgroundImage = nil
        self.stillImageBlendFilter.inputImage = nil
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
        self.drawVideoWithSampleBuffer(sampleBuffer)
    }
    
    
    // AVCapture SETUP
    
    private func addCaptureDeviceInputFromDevicePosition(devicePosition: AVCaptureDevicePosition) {
        do {
            self.captureDevice = self.cameraDeviceFromDevicePosition(devicePosition)
            if self.captureDevice != nil {
                self.captureSession.removeInput(self.currentCaptureDeviceInput)
                self.currentCaptureDeviceInput = try AVCaptureDeviceInput(device: self.captureDevice)
                if self.captureSession.canAddInput(self.currentCaptureDeviceInput) {
                    self.captureSession.addInput(self.currentCaptureDeviceInput)
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
    
    private func cameraDeviceFromDevicePosition(devicePosition: AVCaptureDevicePosition) -> AVCaptureDevice? {
        let captureDevices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for captureDevice in captureDevices as! [AVCaptureDevice] {
            if captureDevice.position == devicePosition {
                return captureDevice;
            }
        }
        return nil;
    }
    
}
