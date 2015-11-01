//
//  CameraViewController.swift
//  explosure
//
//  Created by Bernhard Eiling on 03.10.15.
//  Copyright © 2015 bernhardeiling. All rights reserved.
//

import UIKit
import GLKit

class CameraViewController: UIViewController, PhotoControllerDelegate {
    
    @IBOutlet weak var photoSavedWrapperView: UIView!
    @IBOutlet weak var glView: GLKView?
    let cameraController: CameraController
    
    required init?(coder aCoder: NSCoder) {
        cameraController = CameraController()
        super.init(coder: aCoder)
    }
    
    override func viewDidLoad() {
        cameraController.setupCaptureSessionWithDelegate(self)
        cameraController.glView = glView
        super.viewDidLoad()
    }
    
    @IBAction func stillImageTapRecognizerTapped(sender: UITapGestureRecognizer) {
        cameraController.captureImage()
    }
    
    func photoSavedToPhotoLibrary() {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.photoSavedWrapperView.hidden = false
            self.photoSavedWrapperView.alpha = 1.0
            self.photoSavedWrapperView.transform = CGAffineTransformMakeScale(0.8, 0.8)
            UIView.animateWithDuration(0.3, delay: 1.0, options: .CurveEaseOut, animations: { () -> Void in
                self.photoSavedWrapperView.alpha = 0.0
                self.photoSavedWrapperView.transform = CGAffineTransformIdentity
                }) { (Bool) -> Void in
                    self.photoSavedWrapperView.hidden = true
            }
        }
    }
    
    override func shouldAutorotate() -> Bool {
        return false
    }
}
	