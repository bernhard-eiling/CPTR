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
    
    var completed: Bool {
        return imageCounter >= 2 && image != nil
    }
    var image: CGImage? {
        didSet {
            imageCounter += 1
        }
    }
    var imageOrientation: UIImageOrientation?
    var jpegUrl: NSURL?
    
    private var imageCounter: UInt
    
    init() {
        self.imageCounter = 0
    }

}
