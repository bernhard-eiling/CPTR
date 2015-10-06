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
    
    override init(nibName aNibName: String?, bundle aBundle: NSBundle?) {
        super.init(nibName: aNibName, bundle: aBundle)
    }
    
    required init?(coder aCoder: NSCoder) {
        super.init(coder: aCoder)
        setupBackCamera()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoView()
    }
    
    func setupVideoView() {
        
        ciContext = CIContext(EAGLContext: glContext)
        let glView = GLKView(frame: self.view.bounds, context: glContext)
        self.view.addSubview(glView);
    }
    
    func setupBackCamera() {
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
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        ciImage = CIImage(CVPixelBuffer: pixelBuffer!)
        if glContext != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(glContext)
        }
        
    }
    
    func videoDataOutput() -> AVCaptureVideoDataOutput? {
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL))
        return videoDataOutput;
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
	