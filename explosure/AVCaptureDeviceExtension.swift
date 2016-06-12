//
//  AVCaptureDeviceExtension.swift
//  CPTR
//
//  Created by Bernhard Eiling on 12.06.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import AVFoundation

extension AVCaptureDevice {
    
    class func captureDevice(devicePosition: AVCaptureDevicePosition) -> AVCaptureDevice? {
        let captureDevices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for captureDevice in captureDevices as! [AVCaptureDevice] {
            if captureDevice.position == devicePosition {
                return captureDevice;
            }
        }
        return nil;
    }

    func imageOrientation() -> UIImageOrientation {
        switch position {
        case .Back: do {
            switch UIDevice.currentDevice().orientation {
            case .Portrait:
                return .Right
            case .LandscapeLeft:
                return .Up
            case .LandscapeRight:
                return .Down
            case .PortraitUpsideDown:
                return .Left
            default:
                return .Left
            }
            }
            
        case .Front: do {
            switch UIDevice.currentDevice().orientation {
            case .Portrait:
                return .Left
            case .LandscapeLeft:
                return .Down
            case .LandscapeRight:
                return .Up
            case .PortraitUpsideDown:
                return .Right
            default:
                return .Right
            }
            }
        default:
            return .Left
        }
        return .Left
    }
    
}
