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
    let documentInteractionController: UIDocumentInteractionController
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    required init?(coder aCoder: NSCoder) {
        cameraController = CameraController()
        documentInteractionController = UIDocumentInteractionController()
        super.init(coder: aCoder)
    }
    
    override func viewDidLoad() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "deviceOrientationDidChange", name: UIDeviceOrientationDidChangeNotification, object: nil)
        cameraController.setupCaptureSessionWithDelegate(self)
        cameraController.glView = glView
        super.viewDidLoad()
    }
    
    @IBAction func stillImageTapRecognizerTapped(sender: UITapGestureRecognizer) {
        cameraController.captureImage()
    }
    
    func photoSavedToPhotoLibrary(savedPhoto: UIImage) {
        dispatch_async(dispatch_get_main_queue()) {
            [unowned self] () -> Void in
            self.presentShareViewControllerWithPhoto(savedPhoto)
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
    
    func presentShareViewControllerWithPhoto(photo: UIImage) {
        let shareViewController = ShareViewController(nibName: "ShareViewController", bundle: nil)
        self.presentViewController(shareViewController, animated: true) { () -> Void in
            shareViewController.sharePhoto(photo)
        }
    }
    
    func deviceOrientationDidChange() {
        if(UIDeviceOrientationIsLandscape(UIDevice.currentDevice().orientation)) {
            
        }
        if(UIDeviceOrientationIsPortrait(UIDevice.currentDevice().orientation)) {
            
        }
    }
    
    override func shouldAutorotate() -> Bool {
        return false
    }
}
	