//
//  PhotoController.swift
//  explosure
//
//  Created by Bernhard Eiling on 17.10.15.
//  Copyright © 2015 bernhardeiling. All rights reserved.
//

import Foundation
import Photos

class PhotoController : NSObject {
    
    override init() {
        super.init()
    }
    
    func saveImageToPhotoLibrary(cgImage: CGImage) {
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
            let uiImage = UIImage(CGImage: cgImage)
            PHAssetCreationRequest.creationRequestForAssetFromImage(uiImage)
            }) { (success, error) -> Void in
                if (!success) {
                    NSLog("could not save image to photo library")
                }
        }
    }
    
}