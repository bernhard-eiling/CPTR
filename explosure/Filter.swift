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
            self.filter.setValue(self.inputImage, forKey: "inputImage")
        }
    }
    var inputBackgroundImage: CIImage? {
        didSet {
            self.filter.setValue(self.inputBackgroundImage, forKey: "inputBackgroundImage")
        }
    }
    var outputImage: CIImage? {
        return self.filter.outputImage
    }
    var name: String {
        didSet {
            self.filter = CIFilter(name: self.name)!
            if let inputImage = self.inputImage {
                self.filter.setValue(inputImage, forKey: "inputImage")
            }
            if let inputBackgroundImage = self.inputBackgroundImage {
                self.filter.setValue(inputBackgroundImage, forKey: "inputBackgroundImage")
            }
        }
    }
    private(set) var filter: CIFilter
    
    init (name: String) {
        self.filter = CIFilter(name: name)!
        self.name = name
    }
}
