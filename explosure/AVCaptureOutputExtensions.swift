//
//  AVCaptureOutputExtensions.swift
//  CPTR
//
//  Created by Bernhard Eiling on 17.06.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import AVFoundation

extension AVCaptureVideoDataOutput {
    class func configuredOutput() -> AVCaptureVideoDataOutput {
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)]
        return videoDataOutput
    }
}

extension AVCaptureStillImageOutput {
    class func configuredOutput() -> AVCaptureStillImageOutput {
        let stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput.outputSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32)]
        stillImageOutput.isHighResolutionStillImageOutputEnabled = true
        return stillImageOutput
    }
}
