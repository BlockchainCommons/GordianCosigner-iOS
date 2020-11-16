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
    
    private var spinner = Spinner()
    private var psbt = ""
    private var alertStyle = UIAlertController.Style.actionSheet
    private var psbtToParse:PSBT!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        signOutlet.clipsToBounds = true
        signOutlet.layer.cornerRadius = 5
        
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !FirstTime.firstTimeHere() {
            showAlert(self, "Fatal error", "We were unable to set and save an encryption key to your secure enclave, the app will not function without this key.")
        }
    }
    
    @IBAction func signAction(_ sender: Any) {
        psbt = ""
        psbtToParse = nil
        textView.text = ""
    }
    
    @IBAction func scanQrAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToScanQr", sender: self)
        }
    }    
    
    @IBAction func uploadFileAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Upload a psbt file?", message: "You may upload a .psbt file to sign", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Upload", style: .default, handler: { action in
                self.presentUploader()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func pasteAction(_ sender: Any) {
        if let data = UIPasteboard.general.data(forPasteboardType: "com.apple.traditional-mac-plain-text") {
            guard let string = String(bytes: data, encoding: .utf8) else { return }
            
            psbtValid(string)
        } else if let string = UIPasteboard.general.string {
            
           psbtValid(string)
        } else {
            
            showAlert(self, "Ooops", "Whatever you have pasted does not seem to be valid text.")
        }
    }
    
    @IBAction func seeSignerAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToSigners", sender: self)
        }
    }
    
    private func presentUploader() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)//public.item in iOS and .import
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = .formSheet
            self.present(documentPicker, animated: true, completion: nil)
        }
    }
    
    private func sign() {
//        if psbt != "" {
//            spinner.add(vc: self, description: "signing")
//            
//            PSBTSigner.sign(psbt) { [weak self] (psbt, errorMessage) in
//                guard let self = self else { return }
//                
//                guard let signedPsbt = psbt else {
//                    self.spinner.remove()
//                    showAlert(self, "Something is not right...", errorMessage ?? "unable to sign that psbt: unknown error")
//                    return
//                }
//                
//                DispatchQueue.main.async {
//                    self.textView.text = signedPsbt
//                    self.psbt = signedPsbt
//                    self.export = true
//                    self.signOutlet.setTitle("export", for: .normal)
//                }
//                
//                self.spinner.remove()
//                
//                showAlert(self, "PSBT signed ✅", "You may now export it by tapping the \"export\" button")
//            }
//        } else {
//            showAlert(self, "Add a psbt first", "You may either tap the paste button, scan a QR or upload a .psbt file.")
//        }
    }
    
    private func psbtValid(_ string: String) {
        guard let validPsbt = Keys.psbt(string, .testnet) else {
            setTextView("")
            
            showAlert(self, "⚠️ Invalid psbt", "")
            return
        }
        
        psbtToParse = validPsbt
        psbt = string
        setTextView(string)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToPsbtDetail", sender: self)
        }
    }
    
    private func setTextView(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textView.text = text
        }
    }
    
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToScanQr" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.doneBlock = { [weak self] result in
                    guard let self = self else { return }
                    
                    guard let psbt = result else {
                        showAlert(self, "Ooops", "Whatever you scanned does not seem to be valid text")
                        return
                    }
                    
                    self.psbtValid(psbt)
                }
            }
        }
        
        if segue.identifier == "segueToQRDisplayer" {
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.text = psbt
            }
        }
        
        if segue.identifier == "segueToPsbtDetail" {
            if let vc = segue.destination as? PsbtTableViewController {
                vc.psbt = psbtToParse
            }
        }
    }
}

extension SignerViewController: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if controller.documentPickerMode == .import {
            do {
                let data = try Data(contentsOf: urls[0].absoluteURL)
                psbt = data.base64EncodedString()
                self.psbtValid(psbt)
            } catch {
                spinner.remove()
                showAlert(self, "Ooops", "That is not a recognized format, generally it will be a .psbt file, Gordian Signer is compatible with BIP174.")
            }
        }
    }
    
}
