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
        // Do any additional setup after loading the view.
        if FirstTime.firstTimeHere() {
            guard let randomData = "eeyguyegu".data(using: .utf8),
                let encryptedData = Encryption.encryptData(dataToEncrypt: randomData) else { return }
            
            print("encryptedData: \(encryptedData)")
        }
    }



}

