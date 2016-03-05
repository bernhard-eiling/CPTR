//
//  FilterManager.swift
//  CPTR
//
//  Created by Bernhard on 04.03.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import Foundation

class FilterManager {
    
    var filters: [Filter]?
    let filterNames = ["CILightenBlendMode", "CIDifferenceBlendMode", "CIOverlayBlendMode"]
    var currentIndex = 0 {
        didSet {
            if self.currentIndex >= self.filterNames.count {
                self.currentIndex = 0
            } else if self.currentIndex < 0 {
                self.currentIndex = self.filterNames.count - 1
            }
        }
    }
    
    func next() {
        self.currentIndex++
        if let filters = self.filters {
            for filter in filters {
                filter.name = self.filterNames[self.currentIndex]
            }
        }
    }
    
    func last() {
        self.currentIndex--
        if let filters = self.filters {
            for filter in filters {
                filter.name = self.filterNames[self.currentIndex]
            }
        }
    }
    
}
