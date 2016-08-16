//
//  CameraViewController.swift
//  explosure
//
//  Created by Bernhard Eiling on 15.11.15.
//  Copyright © 2015 bernhardeiling. All rights reserved.
//

import UIKit
import AVFoundation
import GLKit

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private lazy var videoDataOutput: AVCaptureVideoDataOutput = {
        let videoDataOutput = AVCaptureVideoDataOutput.configuredOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL))
        return videoDataOutput
    }()
    
    private lazy var stillImageOutput: AVCaptureStillImageOutput = AVCaptureStillImageOutput.configuredOutput()
    
    private var glContext: EAGLContext
    private var ciContext: CIContext
    private let captureSession: AVCaptureSession
    private var captureDevice: AVCaptureDevice?
    private var currentCaptureDeviceInput: AVCaptureDeviceInput?
    
    @IBOutlet weak var glView: GLKView!
    @IBOutlet var rotatableViews: [UIView]!
    @IBOutlet weak var shareButtonWrapper: UIView!
    @IBOutlet weak var missingPermissionsLabel: UILabel!
    
    private var videoBlendFilter: Filter
    private let stillImageController = StillImageController()
    private var documentInteractionController: UIDocumentInteractionController?
    private var upsideRotationViewsHandler: UpsideRotationViewsHandler?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        fatalError("its not possible to init the CameraViewController with a nib")
    }
    
    required init(coder aCoder: NSCoder) {
        self.videoBlendFilter = Filter(name: "CILightenBlendMode")
        self.glContext = EAGLContext(API: .OpenGLES2)
        self.ciContext = CIContext(EAGLContext: glContext)
        self.captureSession = AVCaptureSession()
        self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        super.init(coder: aCoder)!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        upsideRotationViewsHandler = UpsideRotationViewsHandler(withViews: rotatableViews)
        glView.context = glContext
        glView.enableSetNeedsDisplay = false
        authorizeCamera()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        GAHelper.trackCameraView()
    }
    
    private func authorizeCamera() {
        missingPermissionsLabel.hidden = true
        let authorizationStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        switch authorizationStatus {
        case .NotDetermined:
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { (granted: Bool) -> () in
                guard granted else {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.missingPermissionsLabel.hidden = false
                    })
                    NSLog("camera authorization denied")
                    return
                }
                self.setupSession()
            })
        case .Authorized:
            setupSession()
        case .Denied, .Restricted:
            missingPermissionsLabel.hidden = false
            NSLog("camera authorization denied")
        }
    }
    
    private func setupSession() {
        guard captureSession.canAddOutput(videoDataOutput) else { fatalError() }
        guard captureSession.canAddOutput(stillImageOutput) else { fatalError() }
        captureSession.addOutput(videoDataOutput)
        captureSession.addOutput(stillImageOutput)
        toggle(toDevicePosition: .Back)
    }
    
    @IBAction func captureButtonTapped() {
        guard !stillImageController.compoundImage.completed else {
            resetCapture()
            return
        }
        guard captureSession.running else { return }
        ciImageFromStillImageOutput { (capturedCiImage) in
            guard let capturedCiImage = capturedCiImage else { return }
            self.addCIImageToCompoundImage(capturedCiImage)
        }
    }
    
    private func addCIImageToCompoundImage(ciImage: CIImage) {
        stillImageController.compoundStillImage(fromCIImage: ciImage, devicePosition: captureDevice!.position, completion: { (compoundImage) in
            if compoundImage.completed {
                self.showCompoundImage()
            } else {
                self.setCompoundImageToFilter(compoundImage.image)
            }
        })
    }
    
    private func showCompoundImage() {
        guard let compoundImage = stillImageController.compoundImage.image else { return }
        shareButtonWrapper.hidden = false
        captureSession.stopRunning()
        videoBlendFilter.inputImage = nil
        setCompoundImageToFilter(compoundImage)
        drawFilterImage()
    }
    
    private func resetCapture() {
        videoBlendFilter.inputBackgroundImage = nil
        stillImageController.reset()
        captureSession.startRunning()
        shareButtonWrapper.hidden = true
    }
    
    private func setCompoundImageToFilter(compoundImage: CGImage?) {
        guard   let cgImage = compoundImage,
            let outputImage = videoBlendFilter.outputImage else { return }
        let ciImage = CIImage(CGImage: cgImage)
        let rotatedImage = ciImage.rotated90DegreesRight()
        let scaledAndRotatedImage = rotatedImage.scaledToResolution(CGSize(width: outputImage.extent.size.width, height: outputImage.extent.size.height))
        videoBlendFilter.inputBackgroundImage = scaledAndRotatedImage
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if glContext != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(glContext)
        }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        if !stillImageController.compoundImage.completed {
            var videoImage = CIImage(CVPixelBuffer: imageBuffer)
            if captureDevice?.position == .Front {
                videoImage = videoImage.horizontalFlippedImage()
            }
            let videoFitsGLView = glView.bounds.width * glView.contentScaleFactor == videoImage.extent.width
            if !videoFitsGLView {
                videoImage = videoImage.scaledToResolution(glView.bounds.size.pixelSize)
            }
            videoBlendFilter.inputImage = videoImage
        }
        drawFilterImage()
    }
    
    func drawFilterImage() {
        guard let outputImage = videoBlendFilter.outputImage where glView.frame != CGRectZero else { return }
        glView.bindDrawable()
        ciContext.drawImage(outputImage, inRect: outputImage.extent, fromRect: outputImage.extent)
        glView.display()
    }
    
    @IBAction func shareButtonTapped() {
        guard let jpegUrl = stillImageController.compoundImage.jpegUrl else { return }
        documentInteractionController = UIDocumentInteractionController()
        documentInteractionController!.URL = jpegUrl
        documentInteractionController!.presentOpenInMenuFromRect(CGRectZero, inView: view, animated: true)
    }
    
    @IBAction func toggleCameraButtonTapped() {
        guard let captureDevice = captureDevice else { return }
        switch captureDevice.position {
        case .Back:
            toggle(toDevicePosition: .Front)
        case .Front:
            toggle(toDevicePosition: .Back)
        default:
            toggle(toDevicePosition: .Front)
        }
    }
    
    @IBAction func glViewTapped(tapRecognizer: UITapGestureRecognizer) {
        guard let captureDevice = captureDevice else { return }
        let focusPoint = tapRecognizer.locationInView(glView)
        let normalizedFocusPoint = CGPoint(x: focusPoint.y / view.frame.size.height, y: 1.0 - (focusPoint.x / view.frame.size.width)) // coordinates switch is necessarry due to 90 degree rotation of camera
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
    
    private func ciImageFromStillImageOutput(completion: ((capturedCiImage: CIImage?) -> ())) {
        let stillImageConnection = self.stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        stillImageOutput.captureStillImageAsynchronouslyFromConnection(stillImageConnection, completionHandler: { (imageDataSampleBuffer: CMSampleBuffer?, error: NSError?) -> Void in
            completion(capturedCiImage: self.ciImageFromImageBuffer(imageDataSampleBuffer))
        })
    }
    
    private func toggle(toDevicePosition devicePosition: AVCaptureDevicePosition) {
        do {
            captureSession.stopRunning()
            captureDevice = AVCaptureDevice.captureDevice(devicePosition)
            captureSession.removeInput(currentCaptureDeviceInput)
            currentCaptureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
            if captureSession.canAddInput(currentCaptureDeviceInput) {
                captureSession.addInput(currentCaptureDeviceInput)
            }
            setVideoOrientation(.Portrait)
            captureSession.startRunning()
        } catch {
            NSLog("capture device could not be added to session");
        }
    }
    
    private func setVideoOrientation(orientation: AVCaptureVideoOrientation) {
        guard let videoOutputConnection = videoDataOutput.connectionWithMediaType(AVMediaTypeVideo) else { return }
        if videoOutputConnection.supportsVideoOrientation {
            videoOutputConnection.videoOrientation = orientation
        }
    }
    
    private func ciImageFromImageBuffer(imageSampleBuffer: CMSampleBuffer?) -> CIImage? {
        guard   let sampleBuffer = imageSampleBuffer,
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        return CIImage(CVPixelBuffer: imageBuffer)
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .Portrait
    }
    
    override func shouldAutorotate() -> Bool {
        return false
    }
    
}
