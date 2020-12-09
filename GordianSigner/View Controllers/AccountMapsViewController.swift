//
//  AccountMapsViewController.swift
//  GordianSigner
//
//  Created by Peter on 11/16/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class AccountMapsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var addButton = UIBarButtonItem()
    var editButton = UIBarButtonItem()
    var accountMaps = [[String:Any]]()
    let descriptorParser = DescriptorParser()
    var mapToExport = [String:Any]()
    
    @IBOutlet weak var accountMapTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        addButton.tintColor = .systemTeal
        editButton.tintColor = .systemTeal
        addButton = UIBarButtonItem.init(barButtonSystemItem: .add, target: self, action: #selector(add))
        editButton = UIBarButtonItem.init(barButtonSystemItem: .edit, target: self, action: #selector(editAccounts))
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
        
        if !FirstTime.firstTimeHere() {
            showAlert(self, "Fatal error", "We were unable to set and save an encryption key to your secure enclave, the app will not function without this key.")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        load()
    }
    
    private func load() {
        accountMaps.removeAll()
        
        CoreDataService.retrieveEntity(entityName: .accountMap) { [weak self] (accountMaps, errorDescription) in
            guard let self = self else { return }
            
            guard let accountMaps = accountMaps, accountMaps.count > 0 else {
                if UserDefaults.standard.object(forKey: "createDefaults") == nil {
                    self.createSigner()
                }
                return
            }
            
            for accountMap in accountMaps {
                let str = AccountMapStruct(dictionary: accountMap)
                
                self.accountMaps.append(["accountMap": str])
            }
            
            self.loadKeysets()
        }
    }
    
    private func loadKeysets() {
        CoreDataService.retrieveEntity(entityName: .keyset) { [weak self] (keysets, errorDescription) in
            guard let self = self else { return }
            
            guard let keysets = keysets, keysets.count > 0 else { return }
            
            for (i, accountMap) in self.accountMaps.enumerated() {
                let amStruct = accountMap["accountMap"] as! AccountMapStruct
                self.accountMaps[i]["canSign"] = false
                
                if !amStruct.descriptor.contains("keyset") {
                    self.accountMaps[i]["lifeHash"] = LifeHash.image(amStruct.descriptor)
                }
                
                var participants = ""
                for (k, keyset) in keysets.enumerated() {
                    let keysetStruct = KeysetStruct(dictionary: keyset)
                    
                    if let desc = keysetStruct.bip48SegwitAccount {
                        
                        if amStruct.descriptor.contains(desc) {
                            
                            let participant = keysetStruct.label
                            
                            participants += participant + "\n"
                            
                            CoreDataService.retrieveEntity(entityName: .signer) { (signers, errorDescription) in
                                if let signers = signers, signers.count > 0 {
                                    for signer in signers {
                                        let signerStruct = SignerStruct(dictionary: signer)
                                        if signerStruct.entropy != nil {
                                            if keysetStruct.fingerprint == signerStruct.fingerprint {
                                                self.accountMaps[i]["canSign"] = true
                                                self.accountMaps[i]["signerLifeHash"] = signerStruct.lifeHash
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    if k + 1 == keysets.count {
                        self.accountMaps[i]["participants"] = participants
                    }
                }
                
                if i + 1 == self.accountMaps.count {
                    DispatchQueue.main.async {
                        self.accountMapTable.reloadData()
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return accountMaps.count
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let accountMap = accountMaps[indexPath.section]["accountMap"] as! AccountMapStruct
            delete(accountMap.id, indexPath.section)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "accountMapCell", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.cornerRadius = 8
        cell.layer.borderColor = UIColor.darkGray.cgColor
        cell.layer.borderWidth = 0.5
        
        let accountMap = accountMaps[indexPath.section]["accountMap"] as! AccountMapStruct
        let descriptor = accountMap.descriptor
        let descriptorStruct = descriptorParser.descriptor(descriptor)
        
        let label = cell.viewWithTag(1) as! UILabel
        label.text = accountMap.label
        
        let policy = cell.viewWithTag(2) as! UILabel
        policy.text = descriptorStruct.mOfNType
        
        let script = cell.viewWithTag(3) as! UILabel
        script.text = descriptorStruct.format
        
        let participants = cell.viewWithTag(4) as! UILabel
        participants.text = (accountMaps[indexPath.section]["participants"] as! String)
        
        let isCompleteImage = cell.viewWithTag(5) as! UIImageView
        let completeLabel = cell.viewWithTag(12) as! UILabel
        let addButton = cell.viewWithTag(14) as! UIButton
        if accountMap.descriptor.contains("keyset") {
            isCompleteImage.alpha = 1
            isCompleteImage.image = UIImage(systemName: "circle.lefthalf.fill")
            isCompleteImage.tintColor = .systemYellow
            completeLabel.text = "Account incomplete!"
            addButton.alpha = 1
        } else {
            isCompleteImage.alpha = 0
            isCompleteImage.tintColor = .systemGreen
            completeLabel.text = ""
            addButton.alpha = 0
        }
        
        let signerLifeHash = cell.viewWithTag(6) as! UIImageView
        signerLifeHash.clipsToBounds = true
        signerLifeHash.layer.cornerRadius = 8
        if let lifehash = accountMaps[indexPath.section]["signerLifeHash"] as? Data {
            signerLifeHash.image = UIImage(data: lifehash)
        } else {
            signerLifeHash.image = UIImage(systemName: "questionmark.circle")
            signerLifeHash.tintColor = .darkGray
        }
        
        let editButton = cell.viewWithTag(9) as! UIButton
        editButton.addTarget(self, action: #selector(editLabel(_:)), for: .touchUpInside)
        editButton.restorationIdentifier = "\(indexPath.section)"
        
        let exportButton = cell.viewWithTag(10) as! UIButton
        exportButton.clipsToBounds = true
        exportButton.layer.cornerRadius = 8
        exportButton.restorationIdentifier = "\(indexPath.section)"
        exportButton.addTarget(self, action: #selector(exportQr(_:)), for: .touchUpInside)
        
        let date = cell.viewWithTag(11) as! UILabel
        date.text = accountMap.dateAdded.formatted()
        
        let lifehash = cell.viewWithTag(13) as! UIImageView
        lifehash.clipsToBounds = true
        lifehash.layer.cornerRadius = 8
        if let image = accountMaps[indexPath.section]["lifeHash"] as? UIImage {
            lifehash.image = image
        } else {
            lifehash.image = UIImage(systemName: "rectangle.badge.xmark")
            lifehash.tintColor = .darkGray
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height = 247
        let accountMap = accountMaps[indexPath.section]["accountMap"] as! AccountMapStruct
        let descParser = DescriptorParser()
        let descStruct = descParser.descriptor(accountMap.descriptor)
        let hack = descStruct.mOfNType.replacingOccurrences(of: " of ", with: "*")
        let arr = hack.split(separator: "*")
        if arr.count > 0 {
            if let numberOfCosigners = Int("\(arr[1])") {
                switch numberOfCosigners {
                case _ where numberOfCosigners == 3:
                    height = 257
                case _ where numberOfCosigners == 4:
                    height = 267
                case _ where numberOfCosigners == 5:
                    height = 277
                case _ where numberOfCosigners == 6:
                    height = 287
                case _ where numberOfCosigners == 7:
                    height = 297
                case _ where numberOfCosigners == 8:
                    height = 307
                case _ where numberOfCosigners == 9:
                    height = 317
                case _ where numberOfCosigners == 10:
                    height = 327
                case _ where numberOfCosigners == 11:
                    height = 337
                case _ where numberOfCosigners == 12:
                    height = 347
                case _ where numberOfCosigners == 13:
                    height = 357
                case _ where numberOfCosigners == 14:
                    height = 367
                case _ where numberOfCosigners == 15:
                    height = 377
                default:
                    break
                }
            }
        }
        return CGFloat(height)
    }
    
    @objc func editLabel(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let am = accountMaps[int]["accountMap"] as! AccountMapStruct
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Edit Account Map label"
            let message = ""
            let style = UIAlertController.Style.alert
            let alert = UIAlertController(title: title, message: message, preferredStyle: style)
            
            let save = UIAlertAction(title: "Save", style: .default) { [weak self] (alertAction) in
                guard let self = self else { return }
                
                let textField1 = (alert.textFields![0] as UITextField).text
                
                guard let updatedLabel = textField1, updatedLabel != "" else { return }
                
                self.updateLabel(am.id, updatedLabel)
            }
            
            alert.addTextField { (textField) in
                textField.text = am.label
                textField.isSecureTextEntry = false
                textField.keyboardAppearance = .dark
            }
            
            alert.addAction(save)
            
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            
            self.present(alert, animated:true, completion: nil)
        }
    }
    
    private func updateLabel(_ id: UUID, _ label: String) {
        CoreDataService.updateEntity(id: id, keyToUpdate: "label", newValue: label, entityName: .accountMap) { (success, errorDescription) in
            guard success else { showAlert(self, "Label not saved!", "There was an error updating your label, please let us know about it: \(errorDescription ?? "unknown")"); return }
            
            self.load()
        }
    }
    
    @objc func exportQr(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let accountMapData = (accountMaps[int]["accountMap"] as! AccountMapStruct).accountMap
        
        guard let dict = try? JSONSerialization.jsonObject(with: accountMapData, options: []) as? [String:Any] else { return }
        
        mapToExport = dict
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToExportAccountMap", sender: self)
        }
    }
    
    @objc func add() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            
            let alert = UIAlertController(title: "Add Account Map", message: "You may either create a new account map or import one.", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Import", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    self?.performSegue(withIdentifier: "segueToAddAccountMap", sender: self)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    self?.performSegue(withIdentifier: "createAccountMap", sender: self)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @objc func editAccounts() {
        accountMapTable.setEditing(!accountMapTable.isEditing, animated: true)
        
        if accountMapTable.isEditing {
            editButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(editAccounts))
        } else {
            editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editAccounts))
        }
        
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
    }
    
    @objc func delete(_ id: UUID, _ section: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            
            let alert = UIAlertController(title: "Delete Account Map?", message: "", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
                self.deleteAccountMapNow(id, section)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func deleteAccountMapNow(_ id: UUID, _ section: Int) {
        CoreDataService.deleteEntity(id: id, entityName: .accountMap) { (success, errorDescription) in
            guard success else {
                showAlert(self, "Error deleting Account Map", "We were unable to delete that signer!")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.accountMaps.remove(at: section)
                self?.accountMapTable.deleteSections(IndexSet.init(arrayLiteral: section), with: .fade)
            }
            
            showAlert(self, "", "Account Map deleted ✓")
        }
    }
    
    private func parseAccountMap(_ accountMap: String) {
        guard let dict = try? JSONSerialization.jsonObject(with: accountMap.utf8, options: []) as? [String:Any] else { return }
        
        guard var descriptor = dict["descriptor"] as? String else { return }
        
        guard !descriptor.contains("keyset") else {
            showAlert(self, "Policy maps not yet supported", "You can only create Policy Map's for now, importing is for Account Map's only.")
            return
        }
        
        let accountMapId = UUID()
        
        let descriptorParser = DescriptorParser()
        var descStruct = descriptorParser.descriptor(descriptor)
    
        descriptor = descriptor.replacingOccurrences(of: "'", with: "h")
        let arr = descriptor.split(separator: "#")
        descriptor = "\(arr[0])"
        descStruct = descriptorParser.descriptor(descriptor)
        
        // Add range
        if !descriptor.contains("/0/*") {
            for key in descStruct.multiSigKeys {
                if !key.contains("/0/*") {
                    descriptor = descriptor.replacingOccurrences(of: key, with: key + "/0/*")
                }
            }
        }
        
        descStruct = descriptorParser.descriptor(descriptor)
        
        // If the descriptor is multisig, we sort the keys lexicographically
        if descriptor.contains(",") {
            var dictArray = [[String:String]]()
            
            for keyWithPath in descStruct.keysWithPath {
                let arr = keyWithPath.split(separator: "]")
                if arr.count > 1 {
                    let dict = ["path":"\(arr[0])]", "key": "\(arr[1].replacingOccurrences(of: "))", with: ""))"]
                    dictArray.append(dict)
                }
            }
            
            dictArray.sort(by: {($0["key"]!) < $1["key"]!})
            
            var sortedKeys = ""
            
            for (i, sortedItem) in dictArray.enumerated() {
                let path = sortedItem["path"]!
                let key = sortedItem["key"]!
                let fullKey = path + key
                
                let hack = "wsh(\(fullKey)/0/*)"
                let dp = DescriptorParser()
                let ds = dp.descriptor(hack)
                
                var keyset = [String:Any]()
                keyset["id"] = UUID()
                keyset["label"] = "account map keyset"
                keyset["bip48SegwitAccount"] = fullKey.replacingOccurrences(of: "/0/*", with: "")
                keyset["dateAdded"] = Date()
                keyset["fingerprint"] = ds.fingerprint
                keyset["sharedWith"] = accountMapId
                keyset["dateShared"] = Date()
                
                CoreDataService.saveEntity(dict: keyset, entityName: .keyset) { (_, _) in }
                
                sortedKeys += fullKey
                
                if i + 1 < dictArray.count {
                    sortedKeys += ","
                }
            }
            
            let arr2 = descriptor.split(separator: ",")
            descriptor = "\(arr2[0])," + sortedKeys + "))"
        }
        
        var map = [String:Any]()
        map["blockheight"] = Int64(dict["blockheight"] as? Int ?? 0)
        map["accountMap"] = accountMap.utf8
        map["label"] = dict["label"] as? String ?? "Account map"
        map["id"] = accountMapId
        map["dateAdded"] = Date()
        map["complete"] = descStruct.complete
        map["lifehash"] = LifeHash.hash(descriptor.utf8)
        map["descriptor"] = descriptor
        
        CoreDataService.saveEntity(dict: map, entityName: .accountMap) { [weak self] (success, errorDescription) in
            guard let self = self, success else { return }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .cosignerAdded, object: nil, userInfo: nil)
            }
            
            self.load()
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToAddAccountMap" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.doneBlock = { [weak self] accountMap in
                    guard let self = self, let accountMap = accountMap else { return }
                                        
                    self.parseAccountMap(accountMap)
                }
            }
        }
        
        if segue.identifier == "segueToExportAccountMap" {
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.header = "Account Map"
                vc.descriptionText = mapToExport.json() ?? ""
                vc.isPsbt = false
                vc.text = mapToExport.json() ?? ""
            }
        }
    }
    
    // MARK: - Never used the app before
    
    private func createSigner() {
        guard let words = Keys.seed(),
            let entropy = Keys.entropy(words),
            let encryptedData = Encryption.encrypt(entropy),
            let masterKey = Keys.masterXprv(words, ""),
            let fingerprint = Keys.fingerprint(masterKey),
            let lifeHash = LifeHash.hash(entropy) else {
                showAlert(self, "Error ⚠️", "Something went wrong, private keys not saved!")
                return
        }
        
        var dict = [String:Any]()
        dict["id"] = UUID()
        dict["label"] = UIDevice.current.name
        dict["dateAdded"] = Date()
        dict["lifeHash"] = lifeHash
        dict["fingerprint"] = fingerprint
        dict["entropy"] = encryptedData
        
        CoreDataService.saveEntity(dict: dict, entityName: .signer) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            guard success else {
                showAlert(self, "Error ⚠️", "Failed saving to Core Data!")
                return
            }
            
            self.saveKeysets(masterKey, UIDevice.current.name, fingerprint)
        }
    }
    
    private func saveKeysets(_ masterKey: String, _ label: String, _ xfp: String) {
        let idToShare = UUID()
        var keyset = [String:Any]()
        keyset["id"] = UUID()
        keyset["label"] = label
        keyset["fingerprint"] = xfp
        
        guard let bip48SegwitAccount = Keys.bip48SegwitAccount(masterKey, "main") else {
            showAlert(self, "Key derivation failed", "")
            return
        }
        
        keyset["bip48SegwitAccount"] = bip48SegwitAccount
        keyset["dateAdded"] = Date()
        keyset["dateShared"] = Date()
        keyset["sharedWith"] = idToShare
        
        CoreDataService.saveEntity(dict: keyset, entityName: .keyset) { [weak self] (success, errorDescription) in
            guard let self = self else { return }

            guard success else {
                showAlert(self, "Failed to save keyset", errorDescription ?? "unknown error")
                return
            }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .cosignerAdded, object: nil, userInfo: nil)
            }
            
            self.createPolicyMap(bip48SegwitAccount, idToShare)
        }
    }
    
    private func createPolicyMap(_ keyset: String, _ id: UUID) {
        let desc = "wsh(sortedmulti(2,\(keyset),<keyset #2>,<keyset #3>))"
        
        let accountMap = ["descriptor":desc, "blockheight":0, "label":"Incomplete Account"] as [String : Any]
        let json = accountMap.json() ?? ""
        
        var map = [String:Any]()
        map["blockheight"] = Int64(0)
        map["accountMap"] = json.utf8
        map["label"] = "Incomplete Account"
        map["id"] = id
        map["dateAdded"] = Date()
        map["complete"] = false
        map["descriptor"] = desc
        
        CoreDataService.saveEntity(dict: map, entityName: .accountMap) { [weak self] (success, errorDescription) in
            guard let self = self, success else { return }
            
            UserDefaults.standard.set(true, forKey: "createDefaults")
            self.load()
        }
    }

}
