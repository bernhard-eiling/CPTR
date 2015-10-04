//
//  CameraViewController.swift
//  explosure
//
//  Created by Bernhard Eiling on 03.10.15.
//  Copyright © 2015 bernhardeiling. All rights reserved.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController {
    
    let captureSession = AVCaptureSession()
    
    override init(nibName aNibName: String?, bundle aBundle: NSBundle?) {
        super.init(nibName: aNibName, bundle: aBundle)
    }
    
    required init?(coder aCoder: NSCoder) {
        super.init(coder: aCoder)
        backCameraDevice()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
	