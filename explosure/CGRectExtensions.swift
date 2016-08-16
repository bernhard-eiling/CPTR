//
//  CGRectExtensions.swift
//  CPTR
//
//  Created by Bernhard Eiling on 16.08.16.
//  Copyright © 2016 bernhardeiling. All rights reserved.
//

import Foundation

extension CGSize {
    
    var pixelSize: CGSize {
        let scale = UIScreen.mainScreen().scale
        return CGSize(width: width * scale, height: height * scale)
    }
    
}
