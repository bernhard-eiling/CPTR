//
//  Filter.swift
//  CPTR
//
//  Created by Bernhard on 03.03.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import UIKit

class Filter {
    
    var inputImage: CIImage? {
        didSet {
            filter.setValue(self.inputImage, forKey: "inputImage")
        }
    }
    var inputBackgroundImage: CIImage? {
        didSet {
            filter.setValue(inputBackgroundImage, forKey: "inputBackgroundImage")
        }
    }
    var outputImage: CIImage? {
        return filter.outputImage
    }
    var name: String {
        didSet {
            filter = CIFilter(name: name)!
            if let inputImage = inputImage {
                filter.setValue(inputImage, forKey: "inputImage")
            }
            if let inputBackgroundImage = inputBackgroundImage {
                filter.setValue(inputBackgroundImage, forKey: "inputBackgroundImage")
            }
        }
    }
    private(set) var filter: CIFilter
    
    init (name: String) {
        self.filter = CIFilter(name: name)!
        self.name = name
    }
}
