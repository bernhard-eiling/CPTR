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
        self.glViewController = GLViewController()
        super.init(coder: aCoder)
    }
    
    override func viewDidLoad() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "deviceOrientationDidChange", name: UIDeviceOrientationDidChangeNotification, object: nil)
        self.addChildViewController(self.glViewController)
        self.glViewController.view.frame = self.glViewWrapper.bounds
        self.glViewWrapper.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.glViewWrapper.addSubview(self.glViewController.view)
        super.viewDidLoad()
    }
    
    override func viewDidAppear(animated: Bool) {
        GAHelper.trackCameraView()
        super.viewDidAppear(animated)
    }
    
    @IBAction func captureButtonTapped() {
        self.glViewController.captureImage()
    }
    
    @IBAction func shareButtonTapped() {
        if let blendedPhoto = self.glViewController.blendedPhoto {
            let shareViewController = ShareViewController(nibName: "ShareViewController", bundle: nil)
            self.presentViewController(shareViewController, animated: true) { () -> Void in
                let rotatedUIImage = UIImage(CGImage: blendedPhoto.image, scale: 1.0, orientation: blendedPhoto.imageOrientation)
                shareViewController.sharePhoto(rotatedUIImage)
            }
        }
    }
    
    @IBAction func selfieButtonTapped() {
        self.glViewController.toggleCamera()
    }
    
    @IBAction func focusGestureRecognizerTapped(sender: UITapGestureRecognizer) {
        self.glViewController.focusCaptureDeviceWithPoint(sender.locationInView(self.glViewWrapper))
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
    
    func deviceOrientationDidChange() {
        switch UIDevice.currentDevice().orientation {
        case .Portrait:
            self.rotateRotatableViewsWithTransform(CGAffineTransformIdentity)
            break
        case .LandscapeLeft:
            self.rotateRotatableViewsWithTransform(CGAffineTransformMakeRotation(CGFloat(M_PI_2)))
            break
        case .LandscapeRight:
            self.rotateRotatableViewsWithTransform(CGAffineTransformMakeRotation(-CGFloat(M_PI_2)))
            break
        case .PortraitUpsideDown:
            self.rotateRotatableViewsWithTransform(CGAffineTransformMakeRotation(CGFloat(M_PI)))
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
	