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
    @IBOutlet weak private var passphraseField: UITextField!
    @IBOutlet weak private var addSignerOutlet: UIButton!
    @IBOutlet weak private var aliasField: UITextField!
    @IBOutlet weak private var textView: UITextView!
    
    private var addedWords = [String]()
    private var justWords = [String]()
    private var bip39Words = [String]()
    private var autoCompleteCharacterCount = 0
    private var timer = Timer()
    var doneBlock: (() -> Void)?
    var tempWords = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setDelegates()
        configureTextField()
        configureSignerOutlet()
        configureTextView()
        addTapGesture()
        bip39Words = Bip39Words.valid
    }
    
    @IBAction func shareMnemonicAction(_ sender: Any) {
        if Keys.validMnemonicArray(self.justWords) {
            share(self.justWords.joined(separator: " "))
        } else {
            showAlert(self, "", "Add or generate a valid mnemonic first.")
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
    
    
    @IBAction func generateAction(_ sender: Any) {
        guard let words = Keys.seed() else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textField.text = words
            self.processTextfieldInput()
            self.validWordsAdded()
            self.view.endEditing(true)
        }
    }
    
    @IBAction func addSignerAction(_ sender: Any) {
        if Keys.validMnemonicArray(self.justWords) {
            let passphrase = passphraseField.text ?? ""
            var alias = UIDevice.current.name
            
            if aliasField.text != "" {
                alias = aliasField.text!
            }
            
            let wordData = self.justWords.joined(separator: " ").utf8
            
            guard let encryptedWords = Encryption.encrypt(wordData),
                let masterKey = Keys.masterKey(justWords, passphrase),
                let encryptedMasterKey = Encryption.encrypt(masterKey.utf8),
                let fingerprint = Keys.fingerprint(masterKey),
                let bip48SegwitAccount = Keys.bip48SegwitAccount(masterKey),
                let xprv = Keys.accountXprv(masterKey),
                let encryptedXprv = Encryption.encrypt(xprv.utf8),
                let xpub = Keys.accountXpub(masterKey),
                let lifeHash = LifeHash.hash(xpub) else {
                showAlert(self, "Error ⚠️", "Something went wrong, Cosigner not saved!")
                return
            }
            
            var cosigner = [String:Any]()
            cosigner["id"] = UUID()
            cosigner["label"] = alias
            cosigner["dateAdded"] = Date()
            cosigner["lifehash"] = lifeHash
            cosigner["fingerprint"] = fingerprint
            cosigner["xprv"] = encryptedXprv
            cosigner["bip48SegwitAccount"] = bip48SegwitAccount
            cosigner["words"] = encryptedWords
            cosigner["masterKey"] = encryptedMasterKey
            
            func finish() {
                CoreDataService.saveEntity(dict: cosigner, entityName: .cosigner) { [weak self] (success, errorDescription) in
                    guard let self = self else { return }

                    guard success else {
                        showAlert(self, "Error ⚠️", "Failed saving cosigner to Core Data!")
                        return
                    }
                    
                    DispatchQueue.main.async {
                        showAlert(self, "Cosigner saved", "Account xprv and seed words encrypted and saved 🔐")
                        
                        self.textField.text = ""
                        self.addedWords.removeAll()
                        self.justWords.removeAll()
                        self.bip39Words.removeAll()
                        self.textView.text = ""
                        
                        self.doneBlock!()
                        self.navigationController?.popViewController(animated: true)
                    }
                }
            }
            
            CoreDataService.retrieveEntity(entityName: .account) { (accounts, errorDescription) in
                if let accounts = accounts, accounts.count > 0 {
                    for (i, account) in accounts.enumerated() {
                        let accountStruct = AccountStruct(dictionary: account)
                        if accountStruct.descriptor.contains(bip48SegwitAccount) {
                            cosigner["dateShared"] = Date()
                            cosigner["sharedWith"] = accountStruct.id
                        }
                        
                        if i + 1 == accounts.count {
                            finish()
                        }
                    }
                } else {
                    finish()
                }
            }
        } else {
            showAlert(self, "Invalid bip39 mnemonic", "Take a deep breath and make sure you input your words and optional passphrase correctly. If you add the words one by one autocorrect will assist you to ensure no errors are made.")
        }
    }
    
//    private func saveCosigners(_ masterKey: String, _ label: String, _ xfp: String) {
//        var cosigner = [String:Any]()
//        cosigner["id"] = UUID()
//        cosigner["label"] = label
//        cosigner["fingerprint"] = xfp
//
//        guard let bip48SegwitAccount = Keys.bip48SegwitAccount(masterKey, "main") else {
//                showAlert(self, "Key derivation failed", "")
//                return
//        }
//
//        cosigner["bip48SegwitAccount"] = bip48SegwitAccount
//        cosigner["dateAdded"] = Date()
//
//        func finish() {
//            CoreDataService.saveEntity(dict: cosigner, entityName: .cosigner) { [weak self] (success, errorDescription) in
//                guard let self = self else { return }
//
//                guard success else {
//                    showAlert(self, "Failed to save cosigner", errorDescription ?? "unknown error")
//                    return
//                }
//
//                DispatchQueue.main.async {
//                    NotificationCenter.default.post(name: .cosignerAdded, object: nil, userInfo: nil)
//                }
//
//                if self.tempWords {
//                    self.doneBlock!()
//                    self.navigationController?.popViewController(animated: true)
//                } else {
//                    showAlert(self, "Private keys encrypted and saved 🔐", "")
//
//                    self.textField.text = ""
//                    self.addedWords.removeAll()
//                    self.justWords.removeAll()
//                    self.bip39Words.removeAll()
//                    self.textView.text = ""
//
//                    self.navigationController?.popViewController(animated: true)
//                }
//            }
//        }
//
//        CoreDataService.retrieveEntity(entityName: .account) { (accounts, errorDescription) in
//            if let accounts = accounts, accounts.count > 0 {
//                for (i, account) in accounts.enumerated() {
//                    let accountStruct = AccountStruct(dictionary: account)
//                    if accountStruct.descriptor.contains(bip48SegwitAccount) {
//                        cosigner["dateShared"] = Date()
//                        cosigner["sharedWith"] = accountStruct.id
//                    }
//
//                    if i + 1 == accounts.count {
//                        finish()
//                    }
//                }
//            } else {
//                finish()
//            }
//        }
//    }
    
    @IBAction func removeWordAction(_ sender: Any) {
        guard self.justWords.count > 0 else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textView.text = ""
            self.addedWords.removeAll()
            self.justWords.remove(at: self.justWords.count - 1)
            
            for (i, word) in self.justWords.enumerated() {
                self.addedWords.append("\(i + 1). \(word)\n")
                if i == 0 {
                    self.updatePlaceHolder(wordNumber: i + 1)
                } else {
                    self.updatePlaceHolder(wordNumber: i + 2)
                }
            }
            
            self.textView.textColor = .systemGreen
            self.textView.text = self.addedWords.joined(separator: "")
            
            if Keys.validMnemonicArray(self.justWords) {
                self.validWordsAdded()
            }
        }
    }
    
    @IBAction func addWordAction(_ sender: Any) {
        processTextfieldInput()
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        hideKeyboards()
    }
    
    private func setDelegates() {
        navigationController?.delegate = self
        aliasField.delegate = self
        passphraseField.delegate = self
        textField.delegate = self
    }
    
    private func configureSignerOutlet() {
        addSignerOutlet.showsTouchWhenHighlighted = true
        addSignerOutlet.clipsToBounds = true
        addSignerOutlet.layer.cornerRadius = 8
    }
    
    private func configureTextView() {
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.darkGray.cgColor
        textView.layer.borderWidth = 0.5
    }
    
    private func configureTextField() {
        aliasField.text = UIDevice.current.name
        updatePlaceHolder(wordNumber: 1)
        #if targetEnvironment(macCatalyst)
            textField.becomeFirstResponder()
        #endif
    }
    
    private func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }
    
    private func hideKeyboards() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textField.resignFirstResponder()
            self.textView.resignFirstResponder()
            self.passphraseField.resignFirstResponder()
            self.aliasField.resignFirstResponder()
        }
    }
    
    private func updatePlaceHolder(wordNumber: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textField.attributedPlaceholder = NSAttributedString(string: "add word #\(wordNumber)", attributes: [NSAttributedString.Key.foregroundColor: UIColor.darkGray])
        }
    }
    
    private func processTextfieldInput() {
        guard let textInput = textField.text, textInput != "" else { return }
        
        //check if user pasted more then one word
        let processed = processedCharacters(textInput)
        let userAddedWords = processed.split(separator: " ")
        var multipleWords = [String]()
        
        if userAddedWords.count > 1 {
            
            //user add multiple words
            for (i, word) in userAddedWords.enumerated() {
                var isValid = false
                
                for bip39Word in bip39Words {
                    if word == bip39Word {
                        isValid = true
                        multipleWords.append("\(word)")
                    }
                }
                
                if i + 1 == userAddedWords.count {
                    // we finished our checks
                    if isValid {
                        // they are valid bip39 words
                        addMultipleWords(words: multipleWords)
                        textField.text = ""
                        
                    } else {
                        //they are not all valid bip39 words
                        textField.text = ""
                        showAlert(self, "Error", "At least one of those words is not a valid BIP39 word. We suggest inputting them one at a time so you can utilize our autosuggest feature which will prevent typos.")
                    }
                }
            }
        } else {
            //its one word
            let processedWord = textInput.replacingOccurrences(of: " ", with: "")
            
            for word in bip39Words {
                if processedWord == word {
                    addWord(word: processedWord)
                    textField.text = ""
                }
            }
        }
    }
    
    private func addMultipleWords(words: [String]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textView.text = ""
            self.addedWords.removeAll()
            self.justWords = words
            
            for (i, word) in self.justWords.enumerated() {
                self.addedWords.append("\(i + 1). \(word)\n")
                self.updatePlaceHolder(wordNumber: i + 2)
            }
            
            self.textView.textColor = .systemGreen
            self.textView.text = self.addedWords.joined(separator: "")
            
            guard Keys.validMnemonicArray(self.justWords) else {
                showAlert(self, "Invalid", "Just so you know that is not a valid bip39 mnemonic, if you are inputting a 24 word phrase ignore this message and keep adding your words.")

                return
            }
        }
    }
    
    private func addWord(word: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textView.text = ""
            self.addedWords.removeAll()
            self.justWords.append(word)
            
            for (i, word) in self.justWords.enumerated() {
                self.addedWords.append("\(i + 1). \(word)\n")
                self.updatePlaceHolder(wordNumber: i + 2)
            }
            
            self.textView.textColor = .systemGreen
            self.textView.text = self.addedWords.joined(separator: "")
            
            if Keys.validMnemonicArray(self.justWords) {
                self.validWordsAdded()
            }
            
            self.textField.becomeFirstResponder()
        }
    }
    
    private func validWordsAdded() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textField.resignFirstResponder()
            self.textView.resignFirstResponder()
            self.addSignerOutlet.isEnabled = true
        }
        
        showAlert(self, "Valid ✓", "Ensure you have this mnemonic saved securely offline so that you may recover it if you lose this device!\n\nTap \"encrypt & save\" to encrypt the private keys and save them securely to the device.")
    }
    
    private func processedCharacters(_ string: String) -> String {
        return string.filter("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ ".contains).condenseWhitespace()
    }
    
    func putColorFormattedTextInTextField(autocompleteResult: String, userQuery : String) {
        let coloredString: NSMutableAttributedString = NSMutableAttributedString(string: userQuery + autocompleteResult)
        coloredString.addAttribute(NSAttributedString.Key.foregroundColor,
                                   value: UIColor.systemGreen,
                                   range: NSRange(location: userQuery.count,length:autocompleteResult.count))
        self.textField.attributedText = coloredString
    }
    
    func moveCaretToEndOfUserQueryPosition(userQuery : String) {
        if let newPosition = self.textField.position(from: self.textField.beginningOfDocument, offset: userQuery.count) {
            self.textField.selectedTextRange = self.textField.textRange(from: newPosition, to: newPosition)
        }
        let selectedRange: UITextRange? = textField.selectedTextRange
        textField.offset(from: textField.beginningOfDocument, to: (selectedRange?.start)!)
    }
    
    func formatAutocompleteResult(substring: String, possibleMatches: [String]) -> String {
        var autoCompleteResult = possibleMatches[0]
        autoCompleteResult.removeSubrange(autoCompleteResult.startIndex..<autoCompleteResult.index(autoCompleteResult.startIndex, offsetBy: substring.count))
        autoCompleteCharacterCount = autoCompleteResult.count
        return autoCompleteResult
    }
    
    func getAutocompleteSuggestions(userText: String) -> [String]{
        var possibleMatches: [String] = []
        for item in bip39Words {
            let myString:NSString! = item as NSString
            let substringRange:NSRange! = myString.range(of: userText)
            if (substringRange.location == 0) {
                possibleMatches.append(item)
            }
        }
        return possibleMatches
    }
    
    private func formatSubstring(subString: String) -> String {
        let formatted = String(subString.dropLast(autoCompleteCharacterCount)).lowercased()
        return formatted
    }
    
    private func resetValues() {
        textField.textColor = .white
        autoCompleteCharacterCount = 0
        textField.text = ""
    }
    
    func searchAutocompleteEntriesWIthSubstring(substring: String) {
        let userQuery = substring
        let suggestions = getAutocompleteSuggestions(userText: substring)
        self.textField.textColor = .white
                
        if suggestions.count > 0 {
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { (timer) in
                let autocompleteResult = self.formatAutocompleteResult(substring: substring, possibleMatches: suggestions)
                self.putColorFormattedTextInTextField(autocompleteResult: autocompleteResult, userQuery : userQuery)
                self.moveCaretToEndOfUserQueryPosition(userQuery: userQuery)
            })
            
        } else {
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { [weak self] (timer) in //7
                guard let self = self else { return }
                
                self.textField.text = substring
                
                guard let textInput = self.textField.text else { return }
                
                let processedInput = self.processedCharacters(textInput)
                
                if Keys.validMnemonicString(processedInput) {
                    self.processTextfieldInput()
                    self.textField.textColor = .systemGreen
                    self.validWordsAdded()
                } else {
                    self.textField.textColor = .systemRed
                }
            })
            
            autoCompleteCharacterCount = 0
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

extension AddSignerViewController: UINavigationControllerDelegate {}

extension AddSignerViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.textField {
            processTextfieldInput()
        }
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == self.textField {
            var subString = (textField.text!.capitalized as NSString).replacingCharacters(in: range, with: string)
            subString = formatSubstring(subString: subString)
            if subString.count == 0 {
                resetValues()
            } else {
                searchAutocompleteEntriesWIthSubstring(substring: subString)
            }
        }
        return true
    }
    
}
