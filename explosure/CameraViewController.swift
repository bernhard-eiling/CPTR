//
//  CameraViewController.swift
//  explosure
//
//  Created by Bernhard Eiling on 03.10.15.
//  Copyright © 2015 bernhardeiling. All rights reserved.
//

import UIKit
import AVFoundation
import GLKit

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let captureSession = AVCaptureSession()
    var ciContext = CIContext()
    let glContext = EAGLContext(API: .OpenGLES3)
    var ciImage = CIImage()
    @IBOutlet weak var glView: GLKView!
    let videoDataOutput = AVCaptureVideoDataOutput()
    
    override init(nibName aNibName: String?, bundle aBundle: NSBundle?) {
        super.init(nibName: aNibName, bundle: aBundle)
    }
    
    required init?(coder aCoder: NSCoder) {
        super.init(coder: aCoder)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        setupCaptureSession()
        setupVideoView()
    }
    
    func setupCaptureSession() {
        var captureDeviceInput : AVCaptureDeviceInput
        do {
            if let backCamera = backCameraDevice() {
                captureDeviceInput = try AVCaptureDeviceInput(device: backCamera)
                if captureSession.canAddInput(captureDeviceInput) {
                    captureSession.addInput(captureDeviceInput)
                }
            }
        } catch {
            NSLog("capture device could not be added to session");
        }
        
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt: kCVPixelFormatType_32BGRA)]
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        let videoOutputConnection = videoDataOutput.connectionWithMediaType(AVMediaTypeVideo)
        if videoOutputConnection.supportsVideoOrientation {
            videoOutputConnection.videoOrientation = .Portrait
        }
        let stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput.outputSettings = [AVVideoCodecKey: NSNumber(unsignedInt:kCMVideoCodecType_JPEG)]
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
        }
        
        videoDataOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL))
        let sessionQueue = dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)
        dispatch_async(sessionQueue) { () -> Void in
            self.captureSession.startRunning()
        }
    }
    
    func setupVideoView() {
        ciContext = CIContext(EAGLContext: glContext)
        glView.context = glContext
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            ciImage = CIImage(CVPixelBuffer: pixelBuffer)
        }
        if glContext != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(glContext)
        }
        glView.bindDrawable()
        ciContext.drawImage(ciImage, inRect: ciImage.extent, fromRect: ciImage.extent)
        glView.display()
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
    
    override func shouldAutorotate() -> Bool {
        return false
    }
}
	