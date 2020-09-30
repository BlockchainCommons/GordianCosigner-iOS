//
//  ViewController.swift
//  GordianSigner
//
//  Created by Peter on 9/29/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        if FirstTime.firstTimeHere() {
            
        } else {
            showAlert(self, "Error", "We could not set your master encryption key to the keychain. Please raise an issue on our Github repo.")
        }
    }

    

}

