//
//  CompoundImage.swift
//  CPTR
//
//  Created by Bernhard on 28.02.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import UIKit
import CoreGraphics

class CompoundImage {
    
    var image: CGImage
    var imageOrientation: UIImageOrientation
    
    init(image: CGImage, imageOrientation: UIImageOrientation) {
        self.image = image
        self.imageOrientation = imageOrientation
    }
}
