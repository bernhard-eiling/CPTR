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
    @IBOutlet weak var glViewBlockerView: UIView!
    @IBOutlet weak var shareButtonWrapper: UIView!
    
    
    private var videoBlendFilter: Filter
    private var stillImageController: StillImageController?
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
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
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(deviceOrientationDidChange), name: UIDeviceOrientationDidChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplicationDidBecomeActiveNotification, object: nil)
        glView.context = glContext
        glView.enableSetNeedsDisplay = false
        authorizeCamera()
        if let imageController = StillImageController() {
            stillImageController = imageController
        } else {
            NSLog("unable to init stillimage controller")
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        GAHelper.trackCameraView()
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
                    self.setupCamera()
                }
                else {
                    NSLog("camera authorization denied")
                }
            })
        case .Authorized:
            setupCamera()
        case .Denied, .Restricted:
            NSLog("camera authorization denied")
        }
    }
    
    private func setupCamera() {
        configureCaptureDevice(.Back)
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
        }
        captureSession.startRunning()
    }
    
    @IBAction func captureButtonTapped() {
        guard stillImageController?.compoundImage.completed == false else {
            resetCapture()
            return
        }
        self.ciImageFromStillImageOutput { (capturedCiImage) in
            guard capturedCiImage != nil else { return }
            self.stillImageController?.compoundStillImageFromImage(capturedCiImage!, devicePosition: self.captureDevice!.position, completion: { (compoundImage) in
                if compoundImage.completed {
                    self.haltCapture()
                } else {
                    self.setCompoundImageToFilter(compoundImage.image)
                }
            })
        }
    }
    
    private func haltCapture() {
        guard let compoundImage = stillImageController?.compoundImage.image else { return }
        shareButtonWrapper.hidden = false
        captureSession.stopRunning()
        videoBlendFilter.inputImage = nil
        setCompoundImageToFilter(compoundImage)
        drawFilterImage()
    }
    
    private func resetCapture() {
        videoBlendFilter.inputBackgroundImage = nil
        stillImageController!.reset()
        captureSession.startRunning()
        shareButtonWrapper.hidden = true
    }
   
    private func setCompoundImageToFilter(compoundImage: CGImage?) {
        guard let cgImage = compoundImage else { return }
        let ciImage = CIImage(CGImage: cgImage)
        let rotatedImage = ciImage.rotated90DegreesRight()
        let filterImageRect = videoBlendFilter.outputImage!.extent
        let scaledAndRotatedImage = rotatedImage.scaledToResolution(CGSize(width: filterImageRect.size.width, height: filterImageRect.size.height))
        videoBlendFilter.inputBackgroundImage = scaledAndRotatedImage
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if glContext != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(glContext)
        }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        if stillImageController?.compoundImage.completed == false {
            var videoImage = CIImage(CVPixelBuffer: imageBuffer)
            if captureDevice?.position == .Front {
                videoImage = videoImage.horizontalFlippedImage()
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
        guard stillImageController?.compoundImage.completed == true else { return }
        let shareViewController = ShareViewController()
        presentViewController(shareViewController, animated: true) { () -> Void in
            let rotatedUIImage = UIImage(CGImage:self.stillImageController!.compoundImage.image!, scale: 1.0, orientation:self.stillImageController!.compoundImage.imageOrientation!)
            shareViewController.sharePhoto(rotatedUIImage)
        }
    }
    
    @IBAction func toggleCameraButtonTapped() {
        guard let captureDevice = captureDevice else { return }
        switch captureDevice.position {
        case .Back:
            configureCaptureDevice(.Front)
        case .Front:
            configureCaptureDevice(.Back)
        default:
            configureCaptureDevice(.Front)
        }
    }
    
    @IBAction func glViewTapped(tapRecognizer: UITapGestureRecognizer) {
        let focusPoint = tapRecognizer .locationInView(glView)
        let normalizedFocusPoint = CGPoint(x: focusPoint.y / view.frame.size.height, y: 1.0 - (focusPoint.x / view.frame.size.width)) // coordinates switch is necessarry due to 90 degree rotation of camera
        guard let captureDevice = captureDevice else { return }
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
        dispatch_async(dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)) { () -> Void in
            let stillImageConnection = self.stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
            self.stillImageOutput.captureStillImageAsynchronouslyFromConnection(stillImageConnection, completionHandler: { (imageDataSampleBuffer: CMSampleBuffer?, error: NSError?) -> Void in
                dispatch_async(dispatch_get_main_queue(), {
                    completion(capturedCiImage: self.ciImageFromImageBuffer(imageDataSampleBuffer))
                })
            })
        }
    }
    
    func deviceOrientationDidChange() {
        switch UIDevice.currentDevice().orientation {
        case .Portrait:
            rotateRotatableViewsWithTransform(CGAffineTransformIdentity)
            break
        case .LandscapeLeft:
            rotateRotatableViewsWithTransform(CGAffineTransformMakeRotation(CGFloat(M_PI_2)))
            break
        case .LandscapeRight:
            rotateRotatableViewsWithTransform(CGAffineTransformMakeRotation(-CGFloat(M_PI_2)))
            break
        case .PortraitUpsideDown:
            rotateRotatableViewsWithTransform(CGAffineTransformMakeRotation(CGFloat(M_PI)))
            break
        default:
            break
        }
    }
    
    func rotateRotatableViewsWithTransform(transform: CGAffineTransform) {
        UIView.animateWithDuration(0.3) { () -> Void in
            for rotatableView in self.rotatableViews {
                rotatableView.transform = transform
            }
        }
    }
    
    private func configureCaptureDevice(devicePosition: AVCaptureDevicePosition) {
        glViewBlockerView.hidden = false
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1.3 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            self.glViewBlockerView.hidden = true
        }
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
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .Portrait
    }
    
    override func shouldAutorotate() -> Bool {
        return false
    }
    
}
