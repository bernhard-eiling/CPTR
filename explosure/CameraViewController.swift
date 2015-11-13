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
    
    @IBOutlet var rotatableViews: [UIView]!
    @IBOutlet weak var photoSavedWrapperView: UIView!
    @IBOutlet weak var glView: GLKView?
    let cameraController: CameraController
    let documentInteractionController: UIDocumentInteractionController
    var savedPhoto: UIImage?
    
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
    
    @IBAction func captureButtonTapped() {
        cameraController.captureImage()
    }
    
    @IBAction func shareButtonTapped() {
        self.presentShareViewController()
    }
    
    func photoSavedToPhotoLibrary(savedPhoto: UIImage) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.savedPhoto = savedPhoto
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
    
    func presentShareViewController() {
        if let sharePhoto = self.savedPhoto {
            let shareViewController = ShareViewController(nibName: "ShareViewController", bundle: nil)
            self.presentViewController(shareViewController, animated: true) { () -> Void in
                shareViewController.sharePhoto(sharePhoto)
            }
        }
    }
    
    func deviceOrientationDidChange() {
        switch UIDevice.currentDevice().orientation {
        case .Portrait:
            rotateRotatableViewsWithTransform(CGAffineTransformIdentity)
            break
        case .LandscapeLeft:
            rotateRotatableViewsWithTransform(CGAffineTransformMakeRotation(CGFloat(M_PI_2)))
            break
        case .LandscapeRight:
            rotateRotatableViewsWithTransform(CGAffineTransformMakeRotation(-CGFloat(M_PI_2)))
            break
        case .PortraitUpsideDown:
            rotateRotatableViewsWithTransform(CGAffineTransformMakeRotation(CGFloat(M_PI)))
            break
        default:
            break
        }
    }
    
    func rotateRotatableViewsWithTransform(transform: CGAffineTransform) {
        UIView.animateWithDuration(0.3) { () -> Void in
            for rotatableView in self.rotatableViews {
                rotatableView.transform = transform
            }
        }
    }
    
    override func shouldAutorotate() -> Bool {
        return false
    }
}
	