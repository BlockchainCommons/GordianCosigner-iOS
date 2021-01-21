//
//  LicenseDisclaimerViewController.swift
//  FullyNoded2
//
//  Created by Peter on 25/03/20.
//  Copyright © 2020 Blockchain Commons, LLC. All rights reserved.
//

import UIKit

class LicenseDisclaimerViewController: UIViewController, UITextViewDelegate, UINavigationControllerDelegate {

    @IBOutlet var textView: UITextView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var declineOutlet: UIButton!
    @IBOutlet var acceptOutlet: UIButton!
        
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        navigationController?.delegate = self
        declineOutlet.layer.cornerRadius = 8
        acceptOutlet.layer.cornerRadius = 8
        titleLabel.adjustsFontSizeToFitWidth = true
        textView.delegate = self
    }
    
    @IBAction func acceptAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            UserDefaults.standard.set(true, forKey: "acceptDisclaimer")
            vc.dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func declineAction(_ sender: Any) {
        showAlert(self, "Are you sure?", "Unfortunately if you decline the disclaimer then you can not use the app.")
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
