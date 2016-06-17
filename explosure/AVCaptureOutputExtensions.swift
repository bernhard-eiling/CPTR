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
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt: kCVPixelFormatType_32BGRA)]
        return videoDataOutput
    }
}

extension AVCaptureStillImageOutput {
    class func configuredOutput() -> AVCaptureStillImageOutput {
        let stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput.outputSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        stillImageOutput.highResolutionStillImageOutputEnabled = true
        return stillImageOutput
    }
}
