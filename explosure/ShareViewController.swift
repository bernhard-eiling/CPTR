//
//  ShareViewController.swift
//  explosure
//
//  Created by Bernhard Eiling on 12.11.15.
//  Copyright © 2015 bernhardeiling. All rights reserved.
//

import UIKit

class ShareViewController: UIViewController, UIDocumentInteractionControllerDelegate {
    
    let documentInteractionController: UIDocumentInteractionController
    
    required override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        documentInteractionController = UIDocumentInteractionController()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aCoder: NSCoder) {
        fatalError("NSCoding not supported")
    }

    override func viewDidAppear(animated: Bool) {
        GAHelper.trackShareView()
        super.viewDidAppear(animated)
    }
    
    func sharePhoto(photo: UIImage) {
        let jpegImage = UIImageJPEGRepresentation(photo, 1.0)
        let homePathString = NSTemporaryDirectory() + "/temp_photo.ig";
        let homePathUrl = NSURL(fileURLWithPath: homePathString)
        do {
            try jpegImage!.writeToURL(homePathUrl, options: .DataWritingAtomic)
        } catch {
            NSLog("could not safe temp image")
        }
        documentInteractionController.URL = homePathUrl
        documentInteractionController.UTI = "com.instagram.photo"
        documentInteractionController.delegate = self
        documentInteractionController.presentOpenInMenuFromRect(CGRectZero, inView: view, animated: true)
    }
    
    func documentInteractionControllerDidEndPreview(controller: UIDocumentInteractionController) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    func documentInteractionControllerDidDismissOpenInMenu(controller: UIDocumentInteractionController) {
        dismissViewControllerAnimated(true, completion: nil)
    }

    override func shouldAutorotate() -> Bool {
        return true
    }
}
