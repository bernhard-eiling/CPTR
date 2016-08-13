//
//  UIDocumentInteractionControllerExtensions.swift
//  CPTR
//
//  Created by Bernhard Eiling on 13.08.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import UIKit

extension UIDocumentInteractionController {
    
    class func documentInteractionController(withCompoundImage compoundImage: CompoundImage) -> UIDocumentInteractionController? {
        guard compoundImage.completed else { return nil }
        let documentInteractionController = UIDocumentInteractionController()
        let rotatedUIImage = UIImage(CGImage:compoundImage.image!, scale: 1.0, orientation:compoundImage.imageOrientation!)
        let jpegImage = UIImageJPEGRepresentation(rotatedUIImage, 1.0)
        let homePathString = NSTemporaryDirectory() + "/captr.jpeg";
        let homePathUrl = NSURL(fileURLWithPath: homePathString)
        do {
            try jpegImage!.writeToURL(homePathUrl, options: .DataWritingAtomic)
        } catch {
            NSLog("could not safe temp image")
        }
        documentInteractionController.URL = homePathUrl
        return documentInteractionController
    }
    
}
