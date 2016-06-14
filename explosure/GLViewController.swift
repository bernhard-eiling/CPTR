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

protocol GLViewControllerDelegate {
    func photoSavedToPhotoLibrary(savedPhoto: UIImage)
}

class GLViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    
    private var stillImageOutput: AVCaptureStillImageOutput?
    private let glContext: EAGLContext
    private let ciContext: CIContext
    private let captureSession: AVCaptureSession
    private var captureDevice: AVCaptureDevice? {
        didSet {
            if let stillImageController = self.stillImageController {
                stillImageController.captureDevice = captureDevice
            }
        }
    }
    private var currentCaptureDeviceInput: AVCaptureDeviceInput?
    private var currentvideoDataOutput: AVCaptureVideoDataOutput?
    
    @IBOutlet weak var cameraAuthDeniedLabel: UILabel!
    
    private let photoCapacity = 2
    private var photoCounter = 0
    private var videoBlendFilter: Filter
    private var stillImageBlendFilter: Filter
    private let filterManager: FilterManager
    private var stillImageController: StillImageController?
    
    var blendedPhoto: CompoundImage?
    
    var glViewControllerDelegate: GLViewControllerDelegate?
    
    @IBOutlet var glView: GLKView!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        self.filterManager = FilterManager()
        self.videoBlendFilter = Filter(name: filterManager.filterNames[filterManager.currentIndex])
        self.stillImageBlendFilter = Filter(name: filterManager.filterNames[filterManager.currentIndex])
        self.filterManager.filters = [videoBlendFilter, stillImageBlendFilter]
        self.glContext = EAGLContext(API: .OpenGLES2)
        self.ciContext = CIContext(EAGLContext: glContext)
        self.captureSession = AVCaptureSession()
        self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init(coder aCoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplicationDidBecomeActiveNotification, object: nil)
        authorizeCamera()
    }
    
    func applicationDidBecomeActive() {
        authorizeCamera()
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
            cameraAuthDeniedLabel.hidden = true
            setupCamera()
        case .Denied, .Restricted:
            cameraAuthDeniedLabel.hidden = false
            NSLog("camera authorization denied")
        }
    }
    
    private func setupCamera() {
        // GUARD statement
        if captureDevice != nil {
            return
        }
        addCaptureDeviceInputFromDevicePosition(.Back)
        addStillImageDataOutput()
        
        // not required for still image capture
        //        self.setStillImageOrientation(.PortraitUpsideDown)
        glView.context = self.glContext
        glView.enableSetNeedsDisplay = false
        
        if let imageController = StillImageController(ciContext: ciContext) {
            stillImageController = imageController
        } else {
            NSLog("unable to init stillimage controller")
        }
        
        currentvideoDataOutput = videoDataOutput()
        if let videoDataOutput = currentvideoDataOutput {
            setVideoOrientation(.Portrait, videoDataOutput: videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL))
        }
        dispatch_async(dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)) { () -> Void in
            self.captureSession.startRunning()
        }
    }
    
    @IBAction func filterSwipedLeft(sender: UISwipeGestureRecognizer) {
        filterManager.last()
    }
    
    @IBAction func filterSwipedRight(sender: UISwipeGestureRecognizer) {
        filterManager.next()
    }
    
    func focusCaptureDeviceWithPoint(focusPoint: CGPoint) {
        let normalizedFocusPoint = CGPoint(x: focusPoint.y / glView!.frame.size.height, y: 1.0 - (focusPoint.x / glView!.frame.size.width)) // coordinates switch is necessarry due to 90 degree rotation of camera
        if let captureDevice = captureDevice {
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
        if capacityReached() {
            return
        }
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            videoBlendFilter.inputImage = CIImage(CVPixelBuffer: imageBuffer)
            if videoBlendFilter.outputImage != nil && view != nil {
                glView.bindDrawable()
                //                let flippedCIImage = self.flippedCIImageIfFrontCamera(self.videoBlendFilter.outputImage!)
                //                self.ciContext.drawImage(flippedCIImage, inRect: flippedCIImage.extent, fromRect: flippedCIImage.extent)
                
                // remove later
                ciContext.drawImage(videoBlendFilter.outputImage!, inRect: videoBlendFilter.outputImage!.extent, fromRect: videoBlendFilter.outputImage!.extent)
                glView.display()
            }
        }
    }
    
    func toggleCamera() {
        if let captureDevice = captureDevice {
            switch captureDevice.position {
            case .Back:
                addCaptureDeviceInputFromDevicePosition(.Front)
            case .Front:
                addCaptureDeviceInputFromDevicePosition(.Back)
            default:
                addCaptureDeviceInputFromDevicePosition(.Front)
            }
        }
        if let videoDataOutput = self.currentvideoDataOutput {
            self.setVideoOrientation(.Portrait, videoDataOutput: videoDataOutput)
        }
    }
    
    
    // STILL IMAGE CAPTURE
    // this methode should return an image and should be called somewhere else
    
    func captureImage() {
        if self.capacityReached() {
            self.resetBlender()
            return
        }
        dispatch_async(dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)) { () -> Void in
            let stillImageConnection = self.stillImageOutput?.connectionWithMediaType(AVMediaTypeVideo)
            self.stillImageOutput?.captureStillImageAsynchronouslyFromConnection(stillImageConnection, completionHandler: { (imageDataSampleBuffer: CMSampleBuffer?, error: NSError?) -> Void in
                if let ciImage = self.ciImageFromImageBuffer(imageDataSampleBuffer) {

                    self.stillImageController?.compoundStillImageFromImage(ciImage, completion: { (compoundImage) in
//                        dispatch_async(dispatch_get_main_queue(), {
                            let image = compoundImage.image!
                            let ciImage = CIImage(CGImage: image)
                            let i = 0
//                        })
                    })
                }
            })
        }
    }
    
    private func setFilterBackgroundPhoto(photo: CGImage) {
        let pixelSize = CGSize(width: glView.frame.width * glView.contentScaleFactor, height: glView.frame.height * glView.contentScaleFactor)
        let scaledCGimage: CGImage
        if captureDevice?.position == .Back {
            scaledCGimage = photo.rotate90Degrees(toSize: pixelSize, degrees: M_PI_2)
        } else {
            scaledCGimage = photo.rotate90Degrees(toSize: pixelSize, degrees: -M_PI_2)
        }
        let ciImage = CIImage(CGImage: scaledCGimage)
        //        self.videoBlendFilter.inputBackgroundImage = self.flippedCIImageIfFrontCamera(ciImage)
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
    
    
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if self.glContext != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(self.glContext)
        }
        self.drawVideoWithSampleBuffer(sampleBuffer)
    }
    
    
    // AVCapture SETUP
    
    private func addCaptureDeviceInputFromDevicePosition(devicePosition: AVCaptureDevicePosition) {
        do {
            captureDevice = AVCaptureDevice.captureDevice(devicePosition)
            if captureDevice != nil {
                let backCameraResolution = captureDevice!.activeFormat?.highResolutionStillImageDimensions

                captureSession.removeInput(currentCaptureDeviceInput)
                currentCaptureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
                if captureSession.canAddInput(currentCaptureDeviceInput) {
                    captureSession.addInput(currentCaptureDeviceInput)
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
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            return videoDataOutput
        }
        NSLog("could not add VideoDataOutput to session")
        return nil
    }
    
    private func addStillImageDataOutput() {
        stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput?.outputSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        stillImageOutput?.highResolutionStillImageOutputEnabled = true
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
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
    
    
    // not required for still image capture
    private func setStillImageOrientation(orientation: AVCaptureVideoOrientation) {
        let stillImageOutputConenction = self.stillImageOutput!.connectionWithMediaType(AVMediaTypeVideo)
        if stillImageOutputConenction.supportsVideoOrientation {
            stillImageOutputConenction.videoOrientation = orientation
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
    
}
