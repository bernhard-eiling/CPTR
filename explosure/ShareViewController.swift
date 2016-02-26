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
        self.documentInteractionController = UIDocumentInteractionController()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aCoder: NSCoder) {
        self.documentInteractionController = UIDocumentInteractionController()
        super.init(coder: aCoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
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
        self.documentInteractionController.URL = homePathUrl
        self.documentInteractionController.UTI = "com.instagram.photo"
        self.documentInteractionController.delegate = self
        self.documentInteractionController.presentOpenInMenuFromRect(CGRectZero, inView: self.view, animated: true)
    }
    
    func documentInteractionControllerDidEndPreview(controller: UIDocumentInteractionController) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func documentInteractionControllerDidDismissOpenInMenu(controller: UIDocumentInteractionController) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    override func shouldAutorotate() -> Bool {
        return true
    }
}
