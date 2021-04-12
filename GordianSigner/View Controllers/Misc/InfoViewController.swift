//
//  InfoViewController.swift
//  GordianSigner
//
//  Created by Peter on 1/7/21.
//  Copyright © 2021 Blockchain Commons. All rights reserved.
//

import UIKit

class InfoViewController: UIViewController {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var header: UILabel!
    @IBOutlet weak var blurb: UITextView!
    
    var isAccount = false
    var isSeed = false
    var isCosigner = false
    var isPayment = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        if isAccount {
            setAccount()
//        } else if isSeed {
//            setSeed()
        } else if isCosigner {
            setCosigner()
        } else if isPayment {
            setPayment()
        }
    }
    
    @IBAction func closeAction(_ sender: Any) {
        close()
    }
    
    @IBAction func okAction(_ sender: Any) {
        close()
    }
    
    private func close() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    private func setAccount() {
        let text = """
        Accounts are holders of Bitcoin value. An account map describes the account. An account can also generate addresses, where you will receive money.

        To create an account, define the policy of how many cosigners are possible and how many of those signatures are required, and then import cosigners from your cosigners tab (including the seeds from your seeds tab, which you will be using to sign). You can alternatively import an account map using the QR code from apps like Gordian Wallet, Specter and Fully Noded. When you are done, you can export your account map or your addresses, receive transactions, and make payments on the payments tab.
        """
        
        configureView(icon: UIImage(systemName: "person.2.square.stack")!, blurbText: text, headerLabel: "Accounts")
    }
    
//    private func setSeed() {
//        let text = """
//        Seeds are the foundation of your own signatures. They're the root of HD pubkey pairs; private keys are derived from them to sign payments.
//
//        Enter BIP39 mnemonic phrases for any seeds that you want to sign with (or generate new BIP39 seeds here). When you are done, proceed to the cosigners tab to add the xpubs of any other participants in your multisignature accounts.
//
//        Seeds are always encrypted before being saved.
//        """
//
//        configureView(icon: UIImage(systemName: "person.crop.circle")!, blurbText: text, headerLabel: "Seeds")
//    }
    
    private func setCosigner() {
        let text = """
        Cosigners represent the individuals or devices that can be used to create multisignature accounts.

        Paste xpubs with origin info, crypto-account, crypto-hdkey, crypto-seed, bip39 words or QR codes for everyone who will be participating in a multisignature account. When you are done, proceed to the accounts tab to combine seeds and other cosigners into a multisignature account.
        """
                
        configureView(icon: UIImage(systemName: "person.2")!, blurbText: text, headerLabel: "Cosigners")
    }
    
    private func setPayment() {
        let text = """
        Payments are Bitcoin transactions sent out of your account. They will be imported as partially signed transactions (PSBTs) created by Gordian Wallet or another app.

        Import PSBTs using animated QR codes, text, or files. You can then sign, export, and view details. Another app, such as Gordian Wallet, will finalize the transaction after it's exported.

        Signing is always done offline. Payments are automatically saved when you add a transaction or sign it.
        """
                
        configureView(icon: UIImage(systemName: "bitcoinsign.circle")!, blurbText: text, headerLabel: "Payments")
    }
    
    private func configureView(icon: UIImage, blurbText: String, headerLabel: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.blurb.text = blurbText
            self.icon.image = icon
            self.header.text = headerLabel
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
