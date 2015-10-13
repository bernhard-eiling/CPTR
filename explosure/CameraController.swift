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
                glView.enableSetNeedsDisplay = false
            } else {
                NSLog("wait for nib to init")
            }
        }
    }
    
    private var stillImageOutput: AVCaptureStillImageOutput?
    private let glContext: EAGLContext
    private let ciContext: CIContext
    private let captureSession: AVCaptureSession
    private var blendFilter: CIFilter
    
    override init() {
        glContext = EAGLContext(API: .OpenGLES2)
        ciContext = CIContext(EAGLContext: glContext)
        blendFilter = CIFilter(name: "CISoftLightBlendMode")!
        captureSession = AVCaptureSession()
        super.init()
    }
    
    func setupCaptureSession() {
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        addCaptureDeviceInput()
        addStillImageDataOutput()
        setStillImageOrientation(.Portrait)
        if let videoDataOutput = videoDataOutput() {
            setVideoOrientation(.Portrait, videoDataOutput: videoDataOutput)
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
                    if let sampleBuffer = imageDataSampleBuffer {
                        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                            var capturedImage = CIImage(CVPixelBuffer: imageBuffer)
                            capturedImage = capturedImage.imageByApplyingTransform(CGAffineTransformMakeRotation(-CGFloat(M_PI / 2)))
                            capturedImage = capturedImage.imageByApplyingTransform(CGAffineTransformMakeTranslation(0, 1920))
                            self.blendFilter.setValue(capturedImage, forKey: "inputBackgroundImage")
                        }
                    }
                })
            }
        }
    }
    
    func drawVideoWithSampleBuffer(sampleBuffer: CMSampleBuffer!) {
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            blendFilter.setValue(CIImage(CVPixelBuffer: imageBuffer), forKey: "inputImage")
            if blendFilter.outputImage != nil && glView != nil {
                glView!.bindDrawable()
                ciContext.drawImage(blendFilter.outputImage!, inRect: blendFilter.outputImage!.extent, fromRect: blendFilter.outputImage!.extent)
                glView!.display()
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
        stillImageOutput!.outputSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
            return
        }
        NSLog("could not add StillImageDataOutput to session")
    }
    
    func setVideoOrientation(orientation: AVCaptureVideoOrientation, videoDataOutput: AVCaptureVideoDataOutput) {
        let videoOutputConnection = videoDataOutput.connectionWithMediaType(AVMediaTypeVideo)
        if videoOutputConnection.supportsVideoOrientation {
            videoOutputConnection.videoOrientation = orientation
        }
    }
    
    func setStillImageOrientation(orientation: AVCaptureVideoOrientation) {
        let stillImageOutputConenction = stillImageOutput!.connectionWithMediaType(AVMediaTypeVideo)
        if stillImageOutputConenction.supportsVideoOrientation {
            stillImageOutputConenction.videoOrientation = orientation
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