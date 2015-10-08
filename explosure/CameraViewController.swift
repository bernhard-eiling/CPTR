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
    var glView = GLKView()
    
    override init(nibName aNibName: String?, bundle aBundle: NSBundle?) {
        super.init(nibName: aNibName, bundle: aBundle)
    }
    
    required init?(coder aCoder: NSCoder) {
        super.init(coder: aCoder)
        setupCaptureSession()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoView()
    }
    
    func setupCaptureSession() {
        let backCamera = backCameraDevice()
        let captureDeviceInput : AVCaptureDeviceInput
        do {
            captureDeviceInput = try AVCaptureDeviceInput.init(device: backCamera)
            if captureSession.canAddInput(captureDeviceInput) {
                captureSession.addInput(captureDeviceInput)
            }
        } catch {
            NSLog("capture device could not be added to session");
        }
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("sample_buffer_queue", DISPATCH_QUEUE_SERIAL))
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        let stillImageOutput = AVCaptureStillImageOutput()
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
        }
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        let sessionQueue = dispatch_queue_create("session_queue", DISPATCH_QUEUE_SERIAL)
        dispatch_async(sessionQueue) { () -> Void in
//            self.captureSession.startRunning()
        }
    }
    
    func setupVideoView() {
        ciContext = CIContext(EAGLContext: glContext)
        glView = GLKView(frame: self.view.bounds, context: glContext)
        view.addSubview(glView);
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        ciImage = CIImage(CVPixelBuffer: pixelBuffer!)
        if glContext != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(glContext)
        }
        glView.bindDrawable()
        ciContext.drawImage(ciImage, inRect: ciImage.extent, fromRect: ciImage.extent)
        glView.display()
    }
    
    func backCameraDevice() -> AVCaptureDevice? {
        let captureDevices = AVCaptureDevice.devices()
        for captureDevice in captureDevices as! [AVCaptureDevice] {
            if captureDevice.position == .Back {
                return captureDevice;
            }
        }
        return nil;
    }
}
	