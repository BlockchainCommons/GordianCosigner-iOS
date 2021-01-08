//
//  SeedDetailViewController.swift
//  GordianSigner
//
//  Created by Peter on 12/15/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class SeedDetailViewController: UIViewController {
    
    var signer:SignerStruct!
    
    @IBOutlet weak var mnemonicLabel: UILabel!
    @IBOutlet weak var coSignerLabel: UILabel!
    @IBOutlet weak var passphraseLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        load()
    }
    
    @IBAction func copyMnemonicAction(_ sender: Any) {
        UIPasteboard.general.string = mnemonicLabel.text ?? ""
        
        showAlert(self, "", "Copied ✓")
    }
    
    @IBAction func copyCosignerAction(_ sender: Any) {
        UIPasteboard.general.string = coSignerLabel.text ?? ""
        
        showAlert(self, "", "Copied ✓")
    }
    
    private func load() {
        if let encryptedEntropy = signer.entropy {
            guard let decryptedEntropy = Encryption.decrypt(encryptedEntropy), let mnemonic = Keys.mnemonic(decryptedEntropy) else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.mnemonicLabel.text = mnemonic
            }
        }
        
        if let passphrase = signer.passphrase {
            guard let decryptedPassphrase = Encryption.decrypt(passphrase) else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.passphraseLabel.text = decryptedPassphrase.utf8
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.passphraseLabel.text = "No passphrase"
            }
        }
                
        guard let cosigner = signer.cosigner else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.coSignerLabel.text = ""
            }
            return
        }
        
        print("cosigner: \(cosigner)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.coSignerLabel.text = cosigner
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
