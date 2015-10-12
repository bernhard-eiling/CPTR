//
//  CameraController.swift
//  explosure
//
//  Created by Bernhard Eiling on 12.10.15.
//  Copyright © 2015 bernhardeiling. All rights reserved.
//

import Foundation
import AVFoundation
import GLKit

class CameraController : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    
    var glView: GLKView? {
        didSet {
            if let glView = glView {
                glView.context = glContext
            } else {
                NSLog("wait for nib to init")
            }
        }
    }
    
    private var stillImageOutput: AVCaptureStillImageOutput?
    private let glContext: EAGLContext
    private let ciContext: CIContext
    private let captureSession: AVCaptureSession
    private var image: UIImage?
    
    override init() {
        glContext = EAGLContext(API: .OpenGLES3)
        ciContext = CIContext(EAGLContext: glContext)
        captureSession = AVCaptureSession()
        super.init()
    }
    
    func setupCaptureSession() {
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        addCaptureDeviceInput()
        addStillImageDataOutput()
        if let videoDataOutput = videoDataOutput() {
            setVideoOrientationWithVideoDataOutput(videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL))
        }
        let sessionQueue = dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)
        dispatch_async(sessionQueue) { () -> Void in
            self.captureSession.startRunning()
        }
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if glContext != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(glContext)
        }
        drawVideoWithSampleBuffer(sampleBuffer)
    }
    
    func captureStillImage() {
        let sessionQueue = dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL)
        dispatch_async(sessionQueue) { () -> Void in
            if let stillImageOutput = self.stillImageOutput {
                let stillImageConnection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
                stillImageOutput.captureStillImageAsynchronouslyFromConnection(stillImageConnection, completionHandler: { (imageDataSampleBuffer: CMSampleBuffer?, error: NSError?) -> Void in
//                    var imageData: NSData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
//                    if let image = UIImage(data: imageData) {
//                        self.image = image
//                    }
                    self.captureSession.stopRunning()
                    if imageDataSampleBuffer != nil {
                        self.drawVideoWithSampleBuffer(imageDataSampleBuffer)
                    }
                })
            }
        }
    }
    
    func drawVideoWithSampleBuffer(sampleBuffer: CMSampleBuffer!) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let ciImage = CIImage(CVPixelBuffer: pixelBuffer)
            if let glView = self.glView {
                glView.bindDrawable()
                ciContext.drawImage(ciImage, inRect: ciImage.extent, fromRect: ciImage.extent)
                glView.display()
            } else {
                NSLog("glView not set")
            }
        }
    }
    
    func addCaptureDeviceInput() {
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
        stillImageOutput!.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
            return
        }
        NSLog("could not add StillImageDataOutput to session")
    }
    
    func setVideoOrientationWithVideoDataOutput(videoDataOutput: AVCaptureVideoDataOutput) {
        let videoOutputConnection = videoDataOutput.connectionWithMediaType(AVMediaTypeVideo)
        if videoOutputConnection.supportsVideoOrientation {
            videoOutputConnection.videoOrientation = .Portrait
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