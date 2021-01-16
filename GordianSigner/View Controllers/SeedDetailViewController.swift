//
//  SeedDetailViewController.swift
//  GordianSigner
//
//  Created by Peter on 12/15/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class SeedDetailViewController: UIViewController, UITextFieldDelegate {
    
    var cosigner:CosignerStruct!
    private var qrText = ""
    private var qrDescription = ""
    
    @IBOutlet weak var mnemonicLabel: UILabel!
    @IBOutlet weak var coSignerLabel: UILabel!
    @IBOutlet weak var xprvLabel: UILabel!
    @IBOutlet weak var labelField: UITextField!
    @IBOutlet weak var lifehashImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        labelField.delegate = self
        labelField.returnKeyType = .done
        configureTapGesture()
        load()
    }
    
    private func reloadCosigner() {
        CoreDataService.retrieveEntity(entityName: .cosigner) { [weak self] (cosigners, errorDescription) in
            guard let self = self else { return }
            
            guard let cosigners = cosigners, cosigners.count > 0 else { return }
            
            for cosignerDict in cosigners {
                let cosignerStr = CosignerStruct(dictionary: cosignerDict)
                if cosignerStr.id == self.cosigner.id {
                    self.cosigner = cosignerStr
                    self.reloadCosigners()
                    self.load()
                }
            }
        }
    }
    
    private func deleteMnemonicNow() {
        CoreDataService.updateEntity(id: cosigner.id, keyToUpdate: "words", newValue: "".utf8, entityName: .cosigner) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            guard success else {
                showAlert(self, "", "Mnemonic not deleted!")
                return
            }
            
            CoreDataService.updateEntity(id: self.cosigner.id, keyToUpdate: "masterKey", newValue: "".utf8, entityName: .cosigner) { [weak self] (success, errorDescription) in
                guard let self = self else { return }
                
                guard success else {
                    self.reloadCosigner()
                    showAlert(self, "", "Master key not deleted!")
                    return
                }
                
                self.reloadCosigner()
            }
        }
    }
    
    private func deleteXprvNow() {
        CoreDataService.updateEntity(id: cosigner.id, keyToUpdate: "xprv", newValue: "".utf8, entityName: .cosigner) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            guard success else {
                showAlert(self, "", "Xprv not deleted!")
                return
            }
            
            self.reloadCosigner()
        }
    }
    
    @IBAction func deleteMnemonic(_ sender: Any) {
        if cosigner.words != nil {
            promptToDeleteWords()
        }
    }
    
    @IBAction func exportMnemonic(_ sender: Any) {
        if cosigner.words != nil {
            share(mnemonicLabel.text ?? "")
        }
    }
    
    @IBAction func showQrMnemonic(_ sender: Any) {
        if cosigner.words != nil {
            qrText = mnemonicLabel.text ?? ""
            qrDescription = mnemonicLabel.text ?? ""
            goToQr()
        }
    }
    
    @IBAction func copyMnemonic(_ sender: Any) {
        if cosigner.words != nil {
            UIPasteboard.general.string = mnemonicLabel.text ?? ""
            
            showAlert(self, "", "Copied ✓")
        }
    }
    
    @IBAction func deleteXprv(_ sender: Any) {
        if cosigner.xprv != nil {
            promptToDeleteXprv()
        }
    }
    
    @IBAction func exportXprv(_ sender: Any) {
        if cosigner.xprv != nil {
            share(xprvLabel.text ?? "")
        }
    }
    
    @IBAction func showQrXprv(_ sender: Any) {
        if cosigner.xprv != nil {
            qrText = xprvLabel.text ?? ""
            qrDescription = xprvLabel.text ?? ""
            goToQr()
        }
    }
    
    @IBAction func copyXprv(_ sender: Any) {
        if cosigner.xprv != nil {
            UIPasteboard.general.string = xprvLabel.text ?? ""
            
            showAlert(self, "", "Copied ✓")
        }
    }
        
    private func configureTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        labelField.resignFirstResponder()
    }
    
    @IBAction func copyMnemonicAction(_ sender: Any) {
        UIPasteboard.general.string = mnemonicLabel.text ?? ""
        
        showAlert(self, "", "Copied ✓")
    }
    
    @IBAction func copyCosignerAction(_ sender: Any) {
        UIPasteboard.general.string = cosigner.bip48SegwitAccount
        
        showAlert(self, "", "Copied ✓")
    }
    
    @IBAction func exportCosigner(_ sender: Any) {
        share(cosigner.bip48SegwitAccount ?? "")
    }
    
    @IBAction func showCosignerQr(_ sender: Any) {
        qrText = cosigner.bip48SegwitAccount ?? ""
        qrDescription = cosigner.bip48SegwitAccount ?? ""
        goToQr()
    }
    
    private func goToQr() {
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "segueToCosignerQr", sender: self)
        }
    }
    
    private func promptToDeleteWords() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Delete Mnemonic?", message: "Ensure these words are backed up securely, once deleted they will be gone forever!", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
                self.deleteMnemonicNow()
            }))
                            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToDeleteXprv() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Delete Xprv?", message: "Once deleted this device will no longer be able to sign payments!", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
                self.deleteXprvNow()
            }))
                            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func load() {
        if let words = cosigner.words {
            guard let decryptedWords = Encryption.decrypt(words) else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.mnemonicLabel.text = decryptedWords.utf8
            }
        } else {
            self.mnemonicLabel.text = "No mnemonic on device"
        }
        
        if let xprv = cosigner.xprv {
            guard let decryptedXprv = Encryption.decrypt(xprv) else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.xprvLabel.text = decryptedXprv.utf8
            }
        } else {
            self.xprvLabel.text = "No xprv on device"
        }

        labelField.text = cosigner.label
                
        guard let cosigner = cosigner.bip48SegwitAccount else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.coSignerLabel.text = ""
            }
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.coSignerLabel.text = cosigner
        }
        
        lifehashImageView.layer.magnificationFilter = .nearest
        lifehashImageView.image = UIImage(data: self.cosigner.lifehash)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let newLabel = textField.text else { return }
        
        CoreDataService.updateEntity(id: cosigner.id, keyToUpdate: "label", newValue: newLabel, entityName: .cosigner) { (success, errorDescription) in
            guard success else { showAlert(self, "", "Label not updated!"); return }
        }
        
        reloadCosigners()
    }
    
    private func reloadCosigners() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .cosignerAdded, object: nil, userInfo: nil)
        }
    }
    
    private func share(_ item: Any) {
        DispatchQueue.main.async {
            let itemToShare = [item]
            let activityViewController = UIActivityViewController(activityItems: itemToShare, applicationActivities: nil)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = self.view
                activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
            }
            
            self.present(activityViewController, animated: true) {}
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToCosignerQr" {
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.descriptionText = qrDescription
                vc.header = cosigner.label
                vc.isPsbt = false
                vc.text = qrText
            }
        }
    }
}
