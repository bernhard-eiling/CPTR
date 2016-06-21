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
    
}
