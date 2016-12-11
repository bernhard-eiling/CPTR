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
import RxSwift

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private lazy var videoDataOutput: AVCaptureVideoDataOutput = {
        let videoDataOutput = AVCaptureVideoDataOutput.configuredOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))
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
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    private var videoBlendFilter: Filter
    private let stillImageController = StillImageController()
    private var documentInteractionController: UIDocumentInteractionController?
    private var upsideRotationViewsHandler: UpsideRotationViewsHandler?
    
    var disposeBag = DisposeBag()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("its not possible to init the CameraViewController with a nib")
    }
    
    required init(coder aCoder: NSCoder) {
        self.videoBlendFilter = Filter(name: "CILightenBlendMode")
        self.glContext = EAGLContext(api: .openGLES2)
        self.ciContext = CIContext(eaglContext: glContext)
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        GAHelper.trackCameraView()
    }
    
    private func authorizeCamera() {
        missingPermissionsLabel.isHidden = true
        let authorizationStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        switch authorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (granted: Bool) -> () in
                guard granted else {
                    DispatchQueue.main.async(execute: {
                        self.missingPermissionsLabel.isHidden = false
                    })
                    NSLog("camera authorization denied")
                    return
                }
                self.setupSession()
            })
        case .authorized:
            setupSession()
        case .denied, .restricted:
            missingPermissionsLabel.isHidden = false
            NSLog("camera authorization denied")
        }
    }
    
    private func setupSession() {
        guard captureSession.canAddOutput(videoDataOutput) else { fatalError() }
        guard captureSession.canAddOutput(stillImageOutput) else { fatalError() }
        captureSession.addOutput(videoDataOutput)
        captureSession.addOutput(stillImageOutput)
        toggle(toDevicePosition: .back)
    }
    
    @IBAction func captureButtonTapped() {
        guard !stillImageController.compoundImage.completed else {
            resetCapture()
            return
        }
        guard captureSession.isRunning else { return }
        blurView.isHidden = false
        ciImageFromStillImageOutput { (capturedCiImage) in
            guard let capturedCiImage = capturedCiImage else { return }
            self.addCIImageToCompoundImage(ciImage: capturedCiImage)
        }
    }
    
    private func addCIImageToCompoundImage(ciImage: CIImage) {
        stillImageController.compoundStillImage(fromCIImage: ciImage, devicePosition: captureDevice!.position, completion: { (compoundImage) in
            self.blurView.isHidden = true
            if compoundImage.completed {
                self.showCompoundImage()
            } else {
                self.setCompoundImageToVideoFilter(compoundImage.image)
            }
        })
    }
    
    private func showCompoundImage() {
        guard let compoundImage = stillImageController.compoundImage.image else { return }
        shareButtonWrapper.isHidden = false
        captureSession.stopRunning()
        videoBlendFilter.inputImage = nil
        setCompoundImageToVideoFilter(compoundImage)
        drawFilterImage()
    }
    
    private func resetCapture() {
        videoBlendFilter.inputBackgroundImage = nil
        stillImageController.reset()
        captureSession.startRunning()
        shareButtonWrapper.isHidden = true
    }
    
    private func setCompoundImageToVideoFilter(_ compoundImage: CGImage?) {
        guard let cgImage = compoundImage else { return }
        let ciImage = CIImage(cgImage: cgImage)
        let rotatedImage = ciImage.rotated90DegreesRight()
        let scaledAndRotatedImage = rotatedImage.scale(toView: glView)
        let renderedCGImage = ciContext.createCGImage(scaledAndRotatedImage, from: scaledAndRotatedImage.extent)!
        videoBlendFilter.inputBackgroundImage = CIImage(cgImage: renderedCGImage)
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        if glContext != EAGLContext.current() {
            EAGLContext.setCurrent(glContext)
        }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        if !stillImageController.compoundImage.completed {
            var videoImage = CIImage(cvPixelBuffer: imageBuffer)
            if captureDevice?.position == .front {
                videoImage = videoImage.horizontalFlippedImage()
            }
            videoImage = videoImage.scale(toView: glView)
            videoBlendFilter.inputImage = videoImage
        }
        drawFilterImage()
    }
    
    func drawFilterImage() {
        guard let outputImage = videoBlendFilter.outputImage, glView.frame != CGRect.zero else { return }
        glView.bindDrawable()
        ciContext.draw(outputImage, in: outputImage.extent, from: outputImage.extent)
        glView.display()
    }
    
    @IBAction func shareButtonTapped() {
        guard let jpegUrl = stillImageController.compoundImage.jpegUrl else { return }
        documentInteractionController = UIDocumentInteractionController()
        documentInteractionController!.url = jpegUrl as URL
        documentInteractionController!.presentOpenInMenu(from: CGRect.zero, in: view, animated: true)
    }
    
    @IBAction func toggleCameraButtonTapped() {
        guard let captureDevice = captureDevice else { return }
        switch captureDevice.position {
        case .back:
            toggle(toDevicePosition: .front)
        case .front:
            toggle(toDevicePosition: .back)
        default:
            toggle(toDevicePosition: .front)
        }
    }
    
    @IBAction func glViewTapped(_ tapRecognizer: UITapGestureRecognizer) {
        guard let captureDevice = captureDevice else { return }
        let focusPoint = tapRecognizer.location(in: glView)
        let normalizedFocusPoint = CGPoint(x: focusPoint.y / view.frame.size.height, y: 1.0 - (focusPoint.x / view.frame.size.width)) // coordinates switch is necessarry due to 90 degree rotation of camera
        do {
            try captureDevice.lockForConfiguration()
        } catch {
            NSLog("focus capture device failed")
            return
        }
        if captureDevice.isFocusPointOfInterestSupported {
            captureDevice.focusPointOfInterest = normalizedFocusPoint
            captureDevice.focusMode = .autoFocus
        }
        captureDevice.unlockForConfiguration()
    }
    
    private func ciImageFromStillImageOutput(_ completion: @escaping ((_ capturedCiImage: CIImage?) -> ())) {
        let stillImageConnection = self.stillImageOutput.connection(withMediaType: AVMediaTypeVideo)        
        stillImageOutput.captureStillImageAsynchronously(from: stillImageConnection, completionHandler: { imageDataSampleBuffer, error in
            completion(self.ciImageFromImageBuffer(imageDataSampleBuffer))
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
            setVideoOrientation(.portrait)
            captureSession.startRunning()
        } catch {
            NSLog("capture device could not be added to session");
        }
    }
    
    private func setVideoOrientation(_ orientation: AVCaptureVideoOrientation) {
        guard let videoOutputConnection = videoDataOutput.connection(withMediaType: AVMediaTypeVideo) else { return }
        if videoOutputConnection.isVideoOrientationSupported {
            videoOutputConnection.videoOrientation = orientation
        }
    }
    
    private func ciImageFromImageBuffer(_ imageSampleBuffer: CMSampleBuffer?) -> CIImage? {
        guard   let sampleBuffer = imageSampleBuffer,
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        return CIImage(cvPixelBuffer: imageBuffer)
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var shouldAutorotate : Bool {
        return false
    }
    
}
