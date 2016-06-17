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
    
    private lazy var videoDataOutput: AVCaptureVideoDataOutput = {
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt: kCVPixelFormatType_32BGRA)]
        videoDataOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL))
        return videoDataOutput
    }()
    
    private lazy var stillImageOutput: AVCaptureStillImageOutput = {
        let stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput.outputSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        stillImageOutput.highResolutionStillImageOutputEnabled = true
        return stillImageOutput
    }()
    
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
    
    @IBOutlet weak var cameraAuthDeniedLabel: UILabel!
    
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
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { (granted:Bool) -> Void in
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
        configureCaptureDevice(.Back)
        
        if let imageController = StillImageController(ciContext: ciContext, captureDevice: captureDevice!) {
            stillImageController = imageController
        } else {
            NSLog("unable to init stillimage controller")
        }
        
        glView.context = glContext
        glView.enableSetNeedsDisplay = false
        
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
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
    
    func toggleCamera() {
        if let captureDevice = captureDevice {
            switch captureDevice.position {
            case .Back:
                configureCaptureDevice(.Front)
            case .Front:
                configureCaptureDevice(.Back)
            default:
                configureCaptureDevice(.Front)
            }
        }
    }
    
    func captureImage() {
        self.ciImageFromStillImageOutput { (capturedCiImage) in
            guard capturedCiImage != nil else { return }
            self.stillImageController?.compoundStillImageFromImage(capturedCiImage!, completion: { (compoundImage) in
                guard compoundImage.image != nil else { return }
                let ciImage = CIImage(CGImage: compoundImage.image!)
                let rotatedImage = ciImage.rotated90DegreesRight()
                let filterImageRect = self.videoBlendFilter.outputImage!.extent
                let scaledAndRotatedImage = rotatedImage.scaledToResolution(CGSize(width: filterImageRect.size.width, height: filterImageRect.size.height))
                self.videoBlendFilter.inputBackgroundImage = scaledAndRotatedImage
            })
        }
    }
    
    private func ciImageFromStillImageOutput(completion: ((capturedCiImage: CIImage?) -> ())) {
        dispatch_async(dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)) { () -> Void in
            let stillImageConnection = self.stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
            self.stillImageOutput.captureStillImageAsynchronouslyFromConnection(stillImageConnection, completionHandler: { (imageDataSampleBuffer: CMSampleBuffer?, error: NSError?) -> Void in
                dispatch_async(dispatch_get_main_queue(), {
                    completion(capturedCiImage: self.ciImageFromImageBuffer(imageDataSampleBuffer))
                })
            })
        }
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if self.glContext != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(self.glContext)
        }
        drawVideoWithSampleBuffer(sampleBuffer)
    }
    
    private func drawVideoWithSampleBuffer(sampleBuffer: CMSampleBuffer!) {
        guard view != nil else { return }
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            videoBlendFilter.inputImage = CIImage(CVPixelBuffer: imageBuffer)
            glView.bindDrawable()
            ciContext.drawImage(videoBlendFilter.outputImage!, inRect: videoBlendFilter.outputImage!.extent, fromRect: videoBlendFilter.outputImage!.extent)
            glView.display()
        }
    }
    
    // AVCapture SETUP
    
    private func configureCaptureDevice(devicePosition: AVCaptureDevicePosition) {
        do {
            captureDevice = AVCaptureDevice.captureDevice(devicePosition)
            captureSession.removeInput(currentCaptureDeviceInput)
            currentCaptureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
            if captureSession.canAddInput(currentCaptureDeviceInput) {
                captureSession.addInput(currentCaptureDeviceInput)
            }
            setVideoOrientation(.Portrait)
        } catch {
            NSLog("capture device could not be added to session");
        }
    }
    
    private func setVideoOrientation(orientation: AVCaptureVideoOrientation) {
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        let videoOutputConnection = videoDataOutput.connectionWithMediaType(AVMediaTypeVideo)
        if videoOutputConnection.supportsVideoOrientation {
            videoOutputConnection.videoOrientation = orientation
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
