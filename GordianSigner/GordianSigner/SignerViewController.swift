//
//  SignerViewController.swift
//  GordianSigner
//
//  Created by Peter on 9/30/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit
import LibWally

class SignerViewController: UIViewController {

    @IBOutlet weak private var textView: UITextView!
    @IBOutlet weak private var signOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        signOutlet.clipsToBounds = true
        signOutlet.layer.cornerRadius = 5
        
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
    }
    
    
    @IBAction func uploadFileAction(_ sender: Any) {
    }
    
    @IBAction func pasteAction(_ sender: Any) {
        guard let text = UIPasteboard.general.string else { return }
        psbtValid(text)
    }
    
    @IBAction func seeSignerAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToSigners", sender: self)
        }
    }
    
    private func psbtValid(_ string: String) {
        do {
            let psbt = try PSBT(string, .testnet)
            
            setTextView(psbt.description)
            
            showAlert(self, "Valid psbt ✅", "You can tap the \"sign now\" button to sign this psbt")
        } catch {
            setTextView("")
            
            showAlert(self, "⚠️ Error!", "Invalid psbt")
        }
    }
    
    private func setTextView(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textView.text = text
        }
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
