//
//  CameraViewController.swift
//  explosure
//
//  Created by Bernhard Eiling on 03.10.15.
//  Copyright © 2015 bernhardeiling. All rights reserved.
//

import UIKit
import GLKit

class CameraViewController: UIViewController {
    
    @IBOutlet weak var glView: GLKView!
    let cameraController: CameraController

    required init?(coder aCoder: NSCoder) {
        cameraController = CameraController()
        cameraController.setupCaptureSession()
        super.init(coder: aCoder)
    }
    
    override func viewDidLoad() {
        cameraController.glView = glView
        super.viewDidLoad()
    }

    @IBAction func stillImageTapRecognizerTapped(sender: UITapGestureRecognizer) {
        
    }

    override func shouldAutorotate() -> Bool {
        return false
    }
}
	