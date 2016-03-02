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
    
    var image: CGImage {
        didSet {
            self.imageOrientation = CGImage.imageOrientationAccordingToDeviceOrientation()
        }
    }
    var imageOrientation: UIImageOrientation
    
    init(image: CGImage) {
        self.image = image
        self.imageOrientation = CGImage.imageOrientationAccordingToDeviceOrientation()
    }
}
