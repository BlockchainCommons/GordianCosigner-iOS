//
//  AccountMapsViewController.swift
//  GordianSigner
//
//  Created by Peter on 11/16/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit
import LibWally

class AccountMapsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var addButton = UIBarButtonItem()
    var editButton = UIBarButtonItem()
    var accounts = [[String:Any]]()
    let descriptorParser = DescriptorParser()
    var mapToExport = [String:Any]()
    var accountToView:AccountStruct!
    private var coinType = "0"
    
    @IBOutlet weak var accountMapTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        addButton.tintColor = .systemTeal
        editButton.tintColor = .systemTeal
        addButton = UIBarButtonItem.init(barButtonSystemItem: .add, target: self, action: #selector(add))
        editButton = UIBarButtonItem.init(barButtonSystemItem: .edit, target: self, action: #selector(editAccounts))
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        coinType = UserDefaults.standard.object(forKey: "coinType") as? String ?? "0"
        load()
        if UserDefaults.standard.object(forKey: "seenAccountInfo") == nil {
            showInfo()
            UserDefaults.standard.set(true, forKey: "seenAccountInfo")
        }
    }
    
    @IBAction func infoAction(_ sender: Any) {
        showInfo()
    }
    
    private func load() {
        accounts.removeAll()
        
        CoreDataService.retrieveEntity(entityName: .account) { [weak self] (accounts, errorDescription) in
            guard let self = self else { return }
            
            guard let accounts = accounts, accounts.count > 0 else { return }
            
            for account in accounts {
                let str = AccountStruct(dictionary: account)
                self.accounts.append(["account": str])
            }
            
            self.loadCosigners()
        }
    }
    
    private func loadCosigners() {
        CoreDataService.retrieveEntity(entityName: .cosigner) { [weak self] (cosigners, errorDescription) in
            guard let self = self else { return }
            
            guard let cosigners = cosigners, cosigners.count > 0 else {
                DispatchQueue.main.async {
                    self.accountMapTable.reloadData()
                }
                return
            }
            
            for (i, account) in self.accounts.enumerated() {
                let accountStruct = account["account"] as! AccountStruct
                var participants = ""
                
                for (k, cosigner) in cosigners.enumerated() {
                    let cosignerStruct = CosignerStruct(dictionary: cosigner)
                    
                    if let desc = cosignerStruct.bip48SegwitAccount {
                        
                        if accountStruct.descriptor.contains(desc) {
                            
                            let participant = cosignerStruct.label
                            
                            participants += participant + "\n"
                        }
                    }
                    
                    if k + 1 == cosigners.count {
                        self.accounts[i]["participants"] = participants
                    }
                }
                
                if i + 1 == self.accounts.count {
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
        if accounts.count > 0 {
            return accounts.count
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let account = accounts[indexPath.section]["account"] as! AccountStruct
            delete(account.id, indexPath.section)
        }
    }
    
    private func accountCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = accountMapTable.dequeueReusableCell(withIdentifier: "accountCell", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.cornerRadius = 8
        cell.layer.borderColor = UIColor.darkGray.cgColor
        cell.layer.borderWidth = 0.5
        
        let account = accounts[indexPath.section]["account"] as! AccountStruct
        let descriptor = account.descriptor
        let descriptorStruct = descriptorParser.descriptor(descriptor)
        
        let policy = cell.viewWithTag(2) as! UILabel
        policy.text = descriptorStruct.mOfNType
        
        let script = cell.viewWithTag(3) as! UILabel
        script.text = descriptorStruct.format
        
        let completeLabel = cell.viewWithTag(12) as! UILabel
        let addButton = cell.viewWithTag(14) as! UIButton
        addButton.addTarget(self, action: #selector(addCosigner(_:)), for: .touchUpInside)
        addButton.restorationIdentifier = "\(indexPath.section)"
        
        let seeDetail = cell.viewWithTag(15) as! UIButton
        seeDetail.addTarget(self, action: #selector(seeDetail(_:)), for: .touchUpInside)
        seeDetail.restorationIdentifier = "\(indexPath.section)"
        
        if account.descriptor.contains("keyset") {
            completeLabel.text = "⚠️ Account incomplete!"
            addButton.alpha = 1
            seeDetail.alpha = 0
        } else {
            completeLabel.text = ""
            addButton.alpha = 0
            seeDetail.alpha = 1
        }
        
        let date = cell.viewWithTag(11) as! UILabel
        date.text = account.dateAdded.formatted()
        
        let lifehash = cell.viewWithTag(13) as! LifehashSeedView
        lifehash.background.backgroundColor = cell.backgroundColor
        lifehash.backgroundColor = cell.backgroundColor

        if let lifehashData = account.lifehash {
            lifehash.lifehashImage.image = UIImage(data: lifehashData)
            lifehash.iconImage.image = UIImage(systemName: "person.2.square.stack")
            lifehash.iconLabel.text = account.label
            lifehash.iconImage.alpha = 1
            lifehash.iconLabel.alpha = 1
        } else {
            lifehash.lifehashImage.image = UIImage(systemName: "rectangle.badge.xmark")
            lifehash.lifehashImage.tintColor = .darkGray
            lifehash.iconImage.alpha = 0
            lifehash.iconLabel.alpha = 0
        }
        
        return cell
    }
    
    private func defaultCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = accountMapTable.dequeueReusableCell(withIdentifier: "accountDefaultCell", for: indexPath)
        let button = cell.viewWithTag(1) as! UIButton
        button.addTarget(self, action: #selector(add), for: .touchUpInside)
        return cell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if accounts.count > 0 {
            return accountCell(indexPath)
        } else {
            return defaultCell(indexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if accounts.count > 0 {
            return 152
        } else {
            return 44
        }
    }
    
    @objc func seeDetail(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        accountToView = (accounts[int]["account"] as! AccountStruct)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToAccountDetail", sender: self)
        }
    }
    
//    @objc func seeAddresses(_ sender: UIButton) {
//        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
//
//        let am = accounts[int]["account"] as! AccountStruct
//
//        DispatchQueue.main.async {
//            self.addressesAm = am
//            self.performSegue(withIdentifier: "segueToAddresses", sender: self)
//        }
//    }
    
    @objc func addCosigner(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let am = accounts[int]["account"] as! AccountStruct
        var vettedCosigners = [CosignerStruct]()
        
        CoreDataService.retrieveEntity(entityName: .cosigner) { (cosigners, errorDescription) in
            guard let cosigners = cosigners, cosigners.count > 0 else {
                showAlert(self, "", "No cosigners added yet, add a cosigner first.")
                return
            }
            
            for (i, cosigner) in cosigners.enumerated() {
                let cosignerStruct = CosignerStruct(dictionary: cosigner)
                if !am.descriptor.contains(cosignerStruct.bip48SegwitAccount!) {
                    vettedCosigners.append(cosignerStruct)
                }
                
                if i + 1 == cosigners.count {
                    
                    if vettedCosigners.count > 0 {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            var alertStyle = UIAlertController.Style.actionSheet
                            if (UIDevice.current.userInterfaceIdiom == .pad) {
                              alertStyle = UIAlertController.Style.alert
                            }
                            
                            let alert = UIAlertController(title: "Which Cosigner?", message: "Select the cosigner to be added.", preferredStyle: alertStyle)
                            
                            for vettedCosigner in vettedCosigners {
                                alert.addAction(UIAlertAction(title: vettedCosigner.label, style: .default, handler: { action in
                                    self.updateAccountMap(am, vettedCosigner, int)
                                }))
                            }
                                            
                            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                            alert.popoverPresentationController?.sourceView = self.view
                            self.present(alert, animated: true, completion: nil)
                        }
                    } else {
                        showAlert(self, "", "You can not add duplicate Cosigners to an account, add more Cosigners first.")
                    }
                }
            }
        }
    }
    
    private func sortedDescriptor(_ desc: String) -> String? {
        var dictArray = [[String:String]]()
        let descriptorParser = DescriptorParser()
        let descStruct = descriptorParser.descriptor(desc)
        
        for keyWithPath in descStruct.keysWithPath {
            
            guard keyWithPath.contains("/48h/\(coinType)h/0h/2h") || keyWithPath.contains("/48'/\(coinType)'/0'/2'") else {
                showAlert(self, "Unsupported key origin", "Gordian Cosigner currently only supports the m/48'/\(coinType)'/0'/2' origin, you can toggle on mainnet/testnet in settings to switch between the supported derivation paths.")
                return nil
            }
            
            let arr = keyWithPath.split(separator: "]")
            
            if arr.count > 1 {
                var xpubString = "\(arr[1].replacingOccurrences(of: "))", with: ""))"
                xpubString = xpubString.replacingOccurrences(of: "/0/*", with: "")
                
                guard let xpub = try? HDKey(base58: xpubString) else {
                    showAlert(self, "Key invalid", "Gordian Cosigner does not yet support slip0132 keys. Please ensure your xpub is valid then try again.")
                    return nil
                }
                
                let dict = ["path":"\(arr[0])]", "key": xpub.description]
                dictArray.append(dict)
            }
        }
        
        dictArray.sort(by: {($0["key"]!) < $1["key"]!})
        
        var sortedKeys = ""
        
        for (i, sortedItem) in dictArray.enumerated() {
            let path = sortedItem["path"]!
            let key = sortedItem["key"]!
            let fullKey = path + key
            sortedKeys += fullKey
            
            if i + 1 < dictArray.count {
                sortedKeys += ","
            }
        }
        
        let arr2 = desc.split(separator: ",")
        let descriptor = "\(arr2[0])," + sortedKeys + "))"
        return descriptor
    }
    
    private func updateAccountMap(_ account: AccountStruct, _ cosigner: CosignerStruct, _ section: Int) {
        var desc = account.descriptor
        let descriptorParser = DescriptorParser()
        var descStruct = descriptorParser.descriptor(desc)
        var mofn = descStruct.mOfNType
        mofn = mofn.replacingOccurrences(of: " of ", with: "*")
        let arr = mofn.split(separator: "*")
        guard let n = Int(arr[1]) else { return }
        
        for i in 0...n - 1 {
            if desc.contains("<keyset #\(i + 1)>") {
                desc = desc.replacingOccurrences(of: "<keyset #\(i + 1)>", with: cosigner.bip48SegwitAccount!)
                break
            }
        }
        
        guard var dict = try? JSONSerialization.jsonObject(with: account.map, options: []) as? [String:Any] else { return }
        
        descStruct = descriptorParser.descriptor(desc)
        
        if !desc.contains("keyset") {
            guard let sortedDesc = sortedDescriptor(desc) else { return }

            dict["descriptor"] = sortedDesc
            
            guard let lifehash = LifeHash.hash(sortedDesc.utf8) else {
                showAlert(self, "", "There was an error deriving the descriptors lifehash.")
                return
            }
            
            CoreDataService.updateEntity(id: account.id, keyToUpdate: "lifehash", newValue: lifehash, entityName: .account) { (success, errorDescription) in
                guard success else {
                    showAlert(self, "Lifehash updating failed...", "Please let us know about this bug.")
                    return
                }
            }
            
        } else {
            dict["descriptor"] = desc
        }
        
        let updatedMap = (dict.json() ?? "").utf8
        
        CoreDataService.updateEntity(id: account.id, keyToUpdate: "descriptor", newValue: desc, entityName: .account) { (success, errorDesc) in
            guard success else {
                showAlert(self, "Descriptor updating failed...", "Please let us know about this bug.")
                return
            }
            
            CoreDataService.updateEntity(id: account.id, keyToUpdate: "map", newValue: updatedMap, entityName: .account) { (success, errorDesc) in
                guard success else {
                    showAlert(self, "Account map updating failed...", "Please let us know about this bug.")
                    return
                }
                
                CoreDataService.updateEntity(id: cosigner.id, keyToUpdate: "sharedWith", newValue: account.id, entityName: .cosigner) { (success, errorDescription) in
                    guard success else {
                        showAlert(self, "sharedWith updating failed...", "Please let us know about this bug.")
                        return
                    }
                    
                    CoreDataService.updateEntity(id: cosigner.id, keyToUpdate: "dateShared", newValue: Date(), entityName: .cosigner) { (success, errorDescription) in
                        guard success else {
                            showAlert(self, "dateShared updating failed...", "Please let us know about this bug.")
                            return
                        }
                        
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .cosignerAdded, object: nil, userInfo: nil)
                        }
                        
                        showAlert(self, "", "Account updated ✓")
                        
                        self.load()
                    }
                }
            }
        }
    }
    
    @objc func editLabel(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let account = accounts[int]["account"] as! AccountStruct
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Edit Account Label"
            let message = ""
            let style = UIAlertController.Style.alert
            let alert = UIAlertController(title: title, message: message, preferredStyle: style)
            
            let save = UIAlertAction(title: "Save", style: .default) { [weak self] (alertAction) in
                guard let self = self else { return }
                
                let textField1 = (alert.textFields![0] as UITextField).text
                
                guard let updatedLabel = textField1, updatedLabel != "" else { return }
                
                self.updateLabel(account.id, updatedLabel, account.map)
            }
            
            alert.addTextField { (textField) in
                textField.text = account.label
                textField.isSecureTextEntry = false
                textField.keyboardAppearance = .dark
            }
            
            alert.addAction(save)
            
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            
            self.present(alert, animated:true, completion: nil)
        }
    }
    
    private func updateLabel(_ id: UUID, _ newlabel: String, _ map: Data) {
        CoreDataService.updateEntity(id: id, keyToUpdate: "label", newValue: newlabel, entityName: .account) { (success, errorDescription) in
            guard success else { showAlert(self, "Label not saved!", "There was an error updating your label, please let us know about it: \(errorDescription ?? "unknown")"); return }
            
            guard var accountMap = try? JSONSerialization.jsonObject(with: map, options: []) as? [String:Any] else { return }
            
            accountMap["label"] = newlabel
            
            guard let json = accountMap.json() else { return }
            
            CoreDataService.updateEntity(id: id, keyToUpdate: "map", newValue: json.utf8, entityName: .account) { (success, errorDescription) in
                guard success else { showAlert(self, "Account map not saved!", "There was an error updating the Account Map, please let us know about it: \(errorDescription ?? "unknown")"); return }
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .cosignerAdded, object: nil, userInfo: nil)
                }
                
                self.load()
            }
        }
    }
    
    @objc func exportQr(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let accountMapData = (accounts[int]["account"] as! AccountStruct).map
        
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
            
            let alert = UIAlertController(title: "Add Account", message: "You may either create a new account or import one.", preferredStyle: alertStyle)
            
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
        if accounts.count > 0 {
            accountMapTable.setEditing(!accountMapTable.isEditing, animated: true)
        } else {
            accountMapTable.setEditing(false, animated: true)
        }
        
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
            
            let alert = UIAlertController(title: "Delete Account?", message: "", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
                self.deleteAccountNow(id, section)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func deleteAccountNow(_ id: UUID, _ section: Int) {
        CoreDataService.deleteEntity(id: id, entityName: .account) { (success, errorDescription) in
            guard success else {
                showAlert(self, "Error deleting Account", "")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.accounts.remove(at: section)
                if self?.accounts.count == 0 {
                    self?.editAccounts()
                    self?.accountMapTable.reloadData()
                } else {
                    self?.accountMapTable.deleteSections(IndexSet.init(arrayLiteral: section), with: .fade)
                }
            }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .cosignerAdded, object: nil, userInfo: nil)
            }
        }
    }
    
    private func parseAccountMap(_ accountMap: String) {
        guard let dict = try? JSONSerialization.jsonObject(with: accountMap.utf8, options: []) as? [String:Any],
              var descriptor = dict["descriptor"] as? String,
              !descriptor.contains("keyset") else {
            return
        }
        
        let accountId = UUID()
        
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
        
        guard let sortedDescriptor = sortedDescriptor(descriptor) else { return }
        
        for (i, fullKey) in descStruct.keysWithPath.enumerated() {
            let hack = "wsh(\(fullKey)/0/*)"
            let dp = DescriptorParser()
            let ds = dp.descriptor(hack)
            let bip48SegwitAccount = fullKey.replacingOccurrences(of: "/0/*", with: "")
            
            guard let ur = URHelper.cosignerToUr(bip48SegwitAccount, false), let lifehash = URHelper.fingerprint(ur) else {
                showAlert(self, "", "Error deriving Cosigner lifehash.")
                return
            }
            
            var cosignerToSave = [String:Any]()
            cosignerToSave["id"] = UUID()
            cosignerToSave["label"] = "Cosigner #\(i + 1)"
            cosignerToSave["bip48SegwitAccount"] = bip48SegwitAccount
            cosignerToSave["dateAdded"] = Date()
            cosignerToSave["fingerprint"] = ds.fingerprint
            cosignerToSave["sharedWith"] = accountId
            cosignerToSave["dateShared"] = Date()
            cosignerToSave["lifehash"] = lifehash
            
            // First fetch all existing cosigners to ensure we do not save duplicates
            CoreDataService.retrieveEntity(entityName: .cosigner) { (cosigners, errorDescription) in
                var alreadyExists = false
                
                if let cosigners = cosigners, cosigners.count > 0 {
                    for (i, cosigner) in cosigners.enumerated() {
                        let cosignerStruct = CosignerStruct(dictionary: cosigner)
                        
                        if cosignerStruct.bip48SegwitAccount != nil {
                            if cosignerStruct.bip48SegwitAccount! == bip48SegwitAccount {
                                alreadyExists = true
                            }
                        }
                        
                        if i + 1 == cosigners.count {
                            if !alreadyExists {
                                CoreDataService.saveEntity(dict: cosignerToSave, entityName: .cosigner) { (_, _) in }
                            }
                        }
                    }
                } else {
                    CoreDataService.saveEntity(dict: cosignerToSave, entityName: .cosigner) { (_, _) in }
                }
            }
        }
        
        var account = [String:Any]()
        account["blockheight"] = Int64(dict["blockheight"] as? Int ?? 0)
        account["map"] = accountMap.utf8
        account["label"] = dict["label"] as? String ?? "Account map"
        account["id"] = accountId
        account["dateAdded"] = Date()
        account["complete"] = descStruct.complete
        account["lifehash"] = LifeHash.hash(sortedDescriptor.utf8)
        account["descriptor"] = sortedDescriptor.condenseWhitespace()
        
        CoreDataService.saveEntity(dict: account, entityName: .account) { [weak self] (success, errorDescription) in
            guard let self = self, success else { return }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .cosignerAdded, object: nil, userInfo: nil)
            }
            
            self.load()
        }
    }
    
    private func showInfo() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToAccountsInfo", sender: self)
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        switch segue.identifier {
        case "segueToAddAccountMap":
            guard let vc = segue.destination as? QRScannerViewController else { fallthrough }
            
            vc.doneBlock = { [weak self] accountMap in
                guard let self = self, let accountMap = accountMap else { return }
                
                self.parseAccountMap(accountMap)
            }
            
        case "segueToExportAccountMap":
            guard let vc = segue.destination as? QRDisplayerViewController else { fallthrough }
            
            vc.header = "Account Map"
            vc.descriptionText = mapToExport.json() ?? ""
            vc.isPsbt = false
            vc.text = mapToExport.json() ?? ""
            
        case "segueToAccountDetail":
            guard let vc = segue.destination as? AccountDetailViewController else { fallthrough }
            
            vc.account = self.accountToView
            
        case "createAccountMap":
            guard let vc = segue.destination as? CreateAccountMapViewController else { fallthrough }
            
            vc.doneBlock = { [weak self] accountMap in
                guard let self = self, let accountMap = accountMap else { return }
                
                self.parseAccountMap(accountMap)
            }
            
        case "segueToAccountsInfo":
            guard let vc = segue.destination as? InfoViewController else { fallthrough }
            
            vc.isAccount = true
            
        default:
            break
        }
    }
}
