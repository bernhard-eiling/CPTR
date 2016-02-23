//
//  CameraViewController.swift
//  explosure
//
//  Created by Bernhard Eiling on 03.10.15.
//  Copyright © 2015 bernhardeiling. All rights reserved.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController, GLViewControllerDelegate {
    
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet var rotatableViews: [UIView]!
    @IBOutlet weak var photoSavedWrapperView: UIView!
    @IBOutlet weak var glViewWrapper: UIView!
    @IBOutlet weak var stillImageView: UIImageView!
    let glViewController: GLViewController
    
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    required init?(coder aCoder: NSCoder) {
        glViewController = GLViewController(nibName: "GLViewController", bundle: nil)
        super.init(coder: aCoder)
    }
    
    override func viewDidLoad() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "deviceOrientationDidChange", name: UIDeviceOrientationDidChangeNotification, object: nil)
        addChildViewController(glViewController)
        glViewController.view.frame = self.glViewWrapper.bounds
        self.glViewWrapper.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.glViewWrapper.addSubview(glViewController.view)
        super.viewDidLoad()
    }
    
    @IBAction func captureButtonTapped() {
        if glViewController.savedPhoto != nil {
            captureButton.titleLabel!.text = "CAP"
            self.stillImageView.image = nil
        } else {
            glViewController.captureImage()
        }
    }
    
    @IBAction func shareButtonTapped() {
        presentShareViewController()
    }
    
    @IBAction func focusGestureRecognizerTapped(sender: UITapGestureRecognizer) {
        glViewController.focusCaptureDeviceWithPoint(sender.locationInView(self.glViewWrapper))
    }
    
    func photoSavedToPhotoLibrary(savedPhoto: UIImage) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.stillImageView.image = savedPhoto
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
        if let sharePhoto = glViewController.savedPhoto {
            let shareViewController = ShareViewController(nibName: "ShareViewController", bundle: nil)
            self.presentViewController(shareViewController, animated: true) { () -> Void in
                shareViewController.sharePhoto(UIImage(CGImage:sharePhoto))
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
	