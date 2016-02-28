//
//  BlendedPhoto.swift
//  CPTR
//
//  Created by Bernhard on 28.02.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import UIKit
import CoreGraphics

class BlendedPhoto {
    
    var cgImage: CGImage {
        didSet {
            self.imageOrientation = CGImage.imageOrientationAccordingToDeviceOrientation()
        }
    }
    var imageOrientation: UIImageOrientation
    
    init(cgImage: CGImage) {
        self.cgImage = cgImage
        self.imageOrientation = CGImage.imageOrientationAccordingToDeviceOrientation()
    }
}
