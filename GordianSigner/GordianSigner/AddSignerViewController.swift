//
//  AddSignerViewController.swift
//  GordianSigner
//
//  Created by Peter on 9/30/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class AddSignerViewController: UIViewController {
    
    @IBOutlet weak private var textField: UITextField!
    @IBOutlet weak private var textView: UIView!
    @IBOutlet weak private var passphraseField: UITextField!
    @IBOutlet weak private var addSignerOutlet: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        addSignerOutlet.clipsToBounds = true
        addSignerOutlet.layer.cornerRadius = 8
        
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        
    }
    
    @IBAction func removeWordAction(_ sender: Any) {
    }
    
    @IBAction func addWordAction(_ sender: Any) {
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
