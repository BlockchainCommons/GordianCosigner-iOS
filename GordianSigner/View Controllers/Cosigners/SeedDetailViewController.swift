//
//  SeedDetailViewController.swift
//  GordianSigner
//
//  Created by Peter on 12/15/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class SeedDetailViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
    
    var cosigner:CosignerStruct!
    private var qrText = ""
    private var qrDescription = ""
    private var qrHeader = ""
    let dp = DescriptorParser()
    var desc = ""
    var descStruct:Descriptor!
    private var privCosigner = ""
    private var pubCosigner = ""
    
    @IBOutlet weak var mnemonicLabel: UILabel!
    @IBOutlet weak var coSignerLabel: UILabel!
    @IBOutlet weak var xprvLabel: UILabel!
    @IBOutlet weak var labelField: UITextField!
    @IBOutlet weak var formatSwitch: UISegmentedControl!
    @IBOutlet weak var originLabel: UILabel!
    @IBOutlet weak var lifehashView: LifehashSeedView!
    private var memoEditing = false
    
    @IBOutlet weak var privKeyHeader: UILabel!
    @IBOutlet weak var privKeyDelete: UIButton!
    @IBOutlet weak var privKeyShare: UIButton!
    @IBOutlet weak var privKeyQr: UIButton!
    @IBOutlet weak var privKeyCopy: UIButton!
    @IBOutlet weak var mnemonicHeader: UILabel!
    @IBOutlet weak var mnemonicDelete: UIButton!
    @IBOutlet weak var mnemonicExport: UIButton!
    @IBOutlet weak var mnemonicQr: UIButton!
    @IBOutlet weak var mnemonicCopy: UIButton!
    @IBOutlet weak var memoView: UITextView!
    @IBOutlet weak var shouldSignSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        labelField.delegate = self
        memoView.delegate = self
        labelField.returnKeyType = .done
        configureTapGesture()
        memoView.clipsToBounds = true
        memoView.layer.cornerRadius = 8
        memoView.layer.borderWidth = 0.5
        memoView.layer.borderColor = UIColor.lightGray.cgColor
        desc = "wsh(" + cosigner.bip48SegwitAccount! + "/0/*)"
        descStruct = dp.descriptor(desc)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        load()
    }
    
    @IBAction func switchAction(_ sender: Any) {
        if shouldSignSwitch.isOn {
            // update entity
            CoreDataService.updateEntity(id: cosigner.id, keyToUpdate: "shouldSign", newValue: true, entityName: .cosigner) { (success, errorDescription) in
                guard success else {
                    showAlert(self, "", "There was an issue updating your cosigner, please let us know about it.")
                    return
                }
            }
            
            promptToCreateRequest()
            
        } else {
            if cosigner.xprv != nil || cosigner.words != nil {
                showAlert(self, "", "First you need to delete the private key and seed.")
                self.shouldSignSwitch.isOn = true
            } else {
                CoreDataService.updateEntity(id: cosigner.id, keyToUpdate: "shouldSign", newValue: false, entityName: .cosigner) { (success, errorDescription) in
                    guard success else {
                        showAlert(self, "", "There was an issue updating your cosigner, please let us know about it.")
                        return
                    }
                }
                
                showAlert(self, "", "Cosigner updated ✓")
            }
        }
    }
    
    private func promptToCreateRequest() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Request Private Key?", message: "This setting lets us know you expect to sign payments with this Cosigner. You can create a request for the private key now or you will be automatically prompted when adding a payment.", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Request Private Key", style: .default, handler: { action in
                guard let request = URHelper.requestXprv(self.cosigner.bip48SegwitAccount!, "Gordian Cosigner needs a private key from \(self.cosigner.label) to sign a payment") else {
                    showAlert(self, "", "There was an issue creating the key request, please let us know about it.")
                    return
                }
                
                self.qrDescription = request
                self.qrText = request
                self.qrHeader = "Private Key Request"
                self.goToQr()
            }))
                            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        memoEditing = true
        return true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        memoEditing = false
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if memoEditing {
            if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
                if self.view.frame.origin.y == 0 {
                    self.view.frame.origin.y -= keyboardSize.height
                }
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if memoEditing {
            if self.view.frame.origin.y != 0 {
                self.view.frame.origin.y = 0
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        CoreDataService.updateEntity(id: cosigner.id, keyToUpdate: "memo", newValue: memoView.text ?? "", entityName: .cosigner) { (success, errorDescription) in
            guard success else {
                showAlert(self, "", "There was an error saving the Cosigner memo")
                return
            }
        }
    }
    
    @IBAction func didSwitchFormat(_ sender: Any) {
        if formatSwitch.selectedSegmentIndex == 0 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.pubCosigner = URHelper.cosignerToUr(self.cosigner.bip48SegwitAccount ?? "", false) ?? ""
                self.coSignerLabel.text = self.pubCosigner
            }
            
            if cosigner.xprv != nil {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.shouldSignSwitch.isOn = true
                    self.privCosigner = URHelper.cosignerToUr(self.privCosigner, true) ?? ""
                    self.xprvLabel.text = self.privCosigner
                }
            }
            
            if let words = cosigner.words {
                guard let decryptedWords = Encryption.decrypt(words), let cryptoSeed = URHelper.mnemonicToCryptoSeed(decryptedWords.utf8) else { return }
                            
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.shouldSignSwitch.isOn = true
                    self.mnemonicLabel.text = cryptoSeed
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.coSignerLabel.text = self.descStruct.accountXpub
                self.pubCosigner = "[\(self.descStruct.fingerprint)/48h/\(Keys.coinType)h/0h/2h]\(self.descStruct.accountXpub)"
            }
            
            if let xprv = cosigner.xprv {
                guard let decryptedXprv = Encryption.decrypt(xprv) else { return }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.shouldSignSwitch.isOn = true
                    
                    self.privCosigner = self.cosigner.bip48SegwitAccount!.replacingOccurrences(of: self.descStruct.accountXpub, with: decryptedXprv.utf8)
                    
                    self.xprvLabel.text = decryptedXprv.utf8
                }
            }
            
            if let words = cosigner.words {
                guard let decryptedWords = Encryption.decrypt(words) else { return }
                            
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.shouldSignSwitch.isOn = true
                    
                    self.mnemonicLabel.text = decryptedWords.utf8
                }
            }
        }
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
            qrHeader = cosigner.label
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
            qrHeader = cosigner.label
            qrText = privCosigner
            qrDescription = privCosigner
            goToQr()
        }
    }
    
    @IBAction func copyXprv(_ sender: Any) {
        if cosigner.xprv != nil {
            UIPasteboard.general.string = self.privCosigner
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
        memoView.resignFirstResponder()
    }
    
    @IBAction func copyMnemonicAction(_ sender: Any) {
        UIPasteboard.general.string = mnemonicLabel.text ?? ""
        
        showAlert(self, "", "Copied ✓")
    }
    
    @IBAction func copyCosignerAction(_ sender: Any) {
        UIPasteboard.general.string = pubCosigner
        showAlert(self, "", "Copied ✓")
    }
    
    @IBAction func exportCosigner(_ sender: Any) {
        share(pubCosigner)
    }
    
    @IBAction func showCosignerQr(_ sender: Any) {
        qrHeader = cosigner.label
        qrText = self.pubCosigner
        qrDescription = self.pubCosigner
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.shouldSignSwitch.isOn = false
        }
        
        memoView.text = cosigner.memo ?? "tap to add a memo"
        
        if let words = cosigner.words {
            guard let decryptedWords = Encryption.decrypt(words), let cryptoSeed = URHelper.mnemonicToCryptoSeed(decryptedWords.utf8) else { return }
                        
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.shouldSignSwitch.isOn = true
                
                self.mnemonicLabel.text = cryptoSeed
                
                self.mnemonicCopy.alpha = 1
                self.mnemonicQr.alpha = 1
                self.mnemonicExport.alpha = 1
                self.mnemonicDelete.alpha = 1
                self.mnemonicHeader.alpha = 1
            }
        } else {
            self.mnemonicCopy.alpha = 0
            self.mnemonicQr.alpha = 0
            self.mnemonicExport.alpha = 0
            self.mnemonicDelete.alpha = 0
            self.mnemonicHeader.alpha = 0
            self.mnemonicLabel.text = ""
        }

        labelField.text = cosigner.label
                
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.pubCosigner = URHelper.cosignerToUr(self.cosigner.bip48SegwitAccount ?? "", false) ?? ""
            self.coSignerLabel.text = self.pubCosigner
        }
        
        if let xprv = cosigner.xprv {
            guard let decryptedXprv = Encryption.decrypt(xprv) else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.shouldSignSwitch.isOn = true
                self.privCosigner = URHelper.cosignerToUr("[\(self.descStruct.fingerprint)/48h/\(Keys.coinType)h/0h/2h]\(decryptedXprv.utf8)", true) ?? ""
                self.xprvLabel.text = self.privCosigner
                
                self.privKeyHeader.alpha = 1
                self.privKeyDelete.alpha = 1
                self.privKeyShare.alpha = 1
                self.privKeyCopy.alpha = 1
                self.privKeyQr.alpha = 1
            }
        } else {
            self.privKeyHeader.alpha = 0
            self.privKeyDelete.alpha = 0
            self.privKeyShare.alpha = 0
            self.privKeyCopy.alpha = 0
            self.privKeyQr.alpha = 0
            self.xprvLabel.text = ""
        }
        
        lifehashView.lifehashImage.image = LifeHash.image(cosigner.lifehash) ?? UIImage()
        lifehashView.iconLabel.text = ""
        
        
        originLabel.text = "\(descStruct.fingerprint)/48h/\(Keys.coinType)h/0h/2h"
        
        guard let shouldSign = cosigner.shouldSign else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.shouldSignSwitch.isOn = shouldSign
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let newLabel = textField.text else { return }
        
        CoreDataService.updateEntity(id: cosigner.id, keyToUpdate: "label", newValue: newLabel, entityName: .cosigner) { (success, errorDescription) in
            guard success else { showAlert(self, "", "Label not updated!"); return }
            
            CoreDataService.retrieveEntity(entityName: .cosigner) { [weak self] (cosigners, errorDescription) in
                guard let self = self else { return }
                
                guard let cosigners = cosigners, cosigners.count > 0 else { return }
                
                for cosigner in cosigners {
                    let cosignerStruct = CosignerStruct(dictionary: cosigner)
                    
                    if cosignerStruct.id == self.cosigner.id {
                        self.cosigner = cosignerStruct
                        self.load()
                    }
                }
            }
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
                vc.header = qrHeader
                vc.isPsbt = false
                vc.text = qrText
                
                vc.responseDoneBlock = { [weak self] signer in
                    guard let self = self else { return }
                    
                    guard let addedSigner = signer else { return }
                    
                    if addedSigner.bip48SegwitAccount == self.cosigner!.bip48SegwitAccount! {
                        showAlert(self, "", "Cosigner updated with the correct private key ✓")
                                                
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.cosigner = addedSigner
                            self.desc = "wsh(" + self.cosigner.bip48SegwitAccount! + "/0/*)"
                            self.descStruct = self.dp.descriptor(self.desc)
                            self.load()
                        }
                    }
                }
            }
        }
    }
}
