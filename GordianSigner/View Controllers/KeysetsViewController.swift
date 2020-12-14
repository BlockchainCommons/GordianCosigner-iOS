//
//  KeysetsViewController.swift
//  GordianSigner
//
//  Created by Peter on 11/15/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class KeysetsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var addButton = UIBarButtonItem()
    var editButton = UIBarButtonItem()
    private var keysets = [KeysetStruct]()
    private var signers = [SignerStruct]()
    private var keysetToExport = ""
    private var headerText = ""
    private var subheaderText = ""
    private var lifehashes = [UIImage]()
    let spinner = Spinner()

    @IBOutlet weak private var keysetsTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        keysetsTable.delegate = self
        keysetsTable.dataSource = self
        
        addButton = UIBarButtonItem.init(barButtonSystemItem: .add, target: self, action: #selector(add))
        editButton = UIBarButtonItem.init(barButtonSystemItem: .edit, target: self, action: #selector(editKeysets))
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshTable), name: .cosignerAdded, object: nil)
        load()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        guard let pasteBoard = UIPasteboard.general.string, pasteBoard.lowercased().hasPrefix("ur:crypto-account") else { return }
        
        if let account = URHelper.accountUr(pasteBoard) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                var alertStyle = UIAlertController.Style.actionSheet
                if (UIDevice.current.userInterfaceIdiom == .pad) {
                  alertStyle = UIAlertController.Style.alert
                }
                
                let alert = UIAlertController(title: "Import keyset?", message: "You have a valid keyset on your clipboard, would you like to import it?", preferredStyle: alertStyle)
                
                alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
                    self.addKeyset(account)
                }))
                                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    @objc func add() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToScanKeyset", sender: self)
        }
    }
    
    @objc func refreshTable() {
        load()
    }
    
    private func load() {
        spinner.add(vc: self, description: "loading...")
        keysets.removeAll()
        lifehashes.removeAll()
        signers.removeAll()
        
        CoreDataService.retrieveEntity(entityName: .signer) { (signers, errorDescription) in
            guard let signers = signers else { return }
            
            for signer in signers {
                self.signers.append(SignerStruct(dictionary: signer))
            }
            
            CoreDataService.retrieveEntity(entityName: .keyset) { [weak self] (keysets, errorDescription) in
                guard let self = self else { return }
                
                guard let keysets = keysets, keysets.count > 0 else { self.spinner.remove(); return }
                
                DispatchQueue.background(background: { [weak self] in
                    guard let self = self else { return }
                    for (i, keyset) in keysets.enumerated() {
                        let keysetStruct = KeysetStruct(dictionary: keyset)
                        self.keysets.append(keysetStruct)
                        self.lifehashes.append(LifeHash.image(keysetStruct.bip48SegwitAccount ?? ""))
                        
                        if i + 1 == keysets.count {
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                
                                self.keysetsTable.reloadData()
                                self.spinner.remove()
                            }
                        }
                    }
                }, completion: {})
            }
        }
    }
    
    private func refresh(_ section: Int) {
        spinner.add(vc: self, description: "")
        keysets.removeAll()
        
        CoreDataService.retrieveEntity(entityName: .keyset) { [weak self] (keysets, errorDescription) in
            guard let self = self else { return }
            
            guard let keysets = keysets, keysets.count > 0 else { self.spinner.remove(); return }
            
            for (i, keyset) in keysets.enumerated() {
                let keysetStruct = KeysetStruct(dictionary: keyset)
                self.keysets.append(keysetStruct)
                
                if i + 1 == keysets.count {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.keysetsTable.reloadSections(IndexSet(arrayLiteral: section), with: .none)
                        self.spinner.remove()
                    }
                }
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return keysets.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "keysetCell", for: indexPath)
        configureCell(cell)
        
        if keysets.count > 0 && indexPath.section < keysets.count && lifehashes.count > 0 && indexPath.section < lifehashes.count {
            let keyset = keysets[indexPath.section]
            
            let label = cell.viewWithTag(1) as! UILabel
            label.text = keyset.label
            
            let fingerprintLabel = cell.viewWithTag(2) as! UILabel
            if let key = keyset.bip48SegwitAccount {
                let arr = key.split(separator: "]")
                fingerprintLabel.text = "\(String(describing: arr[0]))]"
            } else {
                fingerprintLabel.text = keyset.fingerprint
            }
            
            let (_, _, lifeHash) = canSign(keyset)
            
            let lifeHashView = cell.viewWithTag(6) as! LifehashSeedSecondary
            lifeHashView.backgroundColor = cell.backgroundColor
            lifeHashView.background.backgroundColor = cell.backgroundColor
            if lifeHash != nil {
                lifeHashView.lifehashImage.image = lifeHash
                lifeHashView.alpha = 1
            } else {
//                lifeHashImage.image = UIImage(systemName: "questionmark.circle")
//                lifeHashImage.tintColor = .lightGray
                lifeHashView.alpha = 0
            }
            
            let dateAddedLabel = cell.viewWithTag(7) as! UILabel
            dateAddedLabel.text = keyset.dateAdded.formatted()

            let addToMapButton = cell.viewWithTag(11) as! UIButton
            addToMapButton.restorationIdentifier = "\(indexPath.section)"
            configureView(addToMapButton)
            addToMapButton.addTarget(self, action: #selector(addToMap(_:)), for: .touchUpInside)
            
            let exportKeysetButton = cell.viewWithTag(9) as! UIButton
            exportKeysetButton.restorationIdentifier = "\(indexPath.section)"
            configureView(exportKeysetButton)
            exportKeysetButton.addTarget(self, action: #selector(exportMultisigKeyset(_:)), for: .touchUpInside)
            
            let isSharedImage = cell.viewWithTag(5) as! UIImageView
            let sharedText = cell.viewWithTag(14) as! UILabel
            if keyset.sharedWith != nil {
                isSharedImage.image = UIImage(systemName: "person.2.square.stack")
                isSharedImage.tintColor = .systemPink
                sharedText.text = "used"
                sharedText.textColor = .systemPink
            } else {
                isSharedImage.image = UIImage(systemName: "person")
                isSharedImage.tintColor = .systemBlue
                sharedText.text = "unused"
                sharedText.textColor = .systemBlue
            }
            
            let editButton = cell.viewWithTag(12) as! UIButton
            editButton.addTarget(self, action: #selector(editLabel(_:)), for: .touchUpInside)
            editButton.restorationIdentifier = "\(indexPath.section)"
            
            let copyTextButton = cell.viewWithTag(15) as! UIButton
            copyTextButton.addTarget(self, action: #selector(copyText(_:)), for: .touchUpInside)
            copyTextButton.restorationIdentifier = "\(indexPath.section)"
            
            let keysetLifehash = cell.viewWithTag(16) as! UIImageView
            keysetLifehash.layer.magnificationFilter = .nearest
            configureView(keysetLifehash)
            keysetLifehash.image = lifehashes[indexPath.section]
            
            return cell
        } else {
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 215
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let keyset = keysets[indexPath.section]
            deleteKeyset(keyset.id, indexPath.section)
        }
    }
    
    private func configureCell(_ cell: UITableViewCell) {
        cell.selectionStyle = .none
        cell.clipsToBounds = true
        cell.layer.cornerRadius = 8
        cell.layer.borderColor = UIColor.darkGray.cgColor
        cell.layer.borderWidth = 0.5
    }
    
    private func configureView(_ view: UIView) {
        view.clipsToBounds = true
        view.layer.cornerRadius = 8
    }
    
    private func canSign(_ keyset: KeysetStruct) -> (isHot: Bool, isMine: Bool, lifeHash: UIImage?) {
        var isHot = false
        var isMine = false
        var lifeHash:UIImage?
        
        for signer in signers {
            if keyset.fingerprint == signer.fingerprint {
                isMine = true
                lifeHash = UIImage(data: signer.lifeHash)
                
                if signer.entropy != nil {
                    isHot = true
                }
            }
        }
        
        return (isHot, isMine, lifeHash)
    }
    
    @objc func copyText(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let keyset = keysets[int]
        
        UIPasteboard.general.string = keyset.bip48SegwitAccount
        showAlert(self, "", "Cosigner text copied ✓")
    }
    
    @objc func editLabel(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let keyset = keysets[int]
        
        promptToEditLabel(keyset)
    }
    
    private func promptToEditLabel(_ keyset: KeysetStruct) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Edit keyset label"
            let message = ""
            let style = UIAlertController.Style.alert
            let alert = UIAlertController(title: title, message: message, preferredStyle: style)
            
            let save = UIAlertAction(title: "Save", style: .default) { [weak self] (alertAction) in
                guard let self = self else { return }
                
                let textField1 = (alert.textFields![0] as UITextField).text
                
                guard let updatedLabel = textField1, updatedLabel != "" else { return }
                
                self.updateLabel(keyset.id, updatedLabel)
            }
            
            alert.addTextField { (textField) in
                textField.text = keyset.label
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
        CoreDataService.updateEntity(id: id, keyToUpdate: "label", newValue: label, entityName: .keyset) { (success, errorDescription) in
            guard success else { showAlert(self, "Label not saved!", "There was an error updating your label, please let us know about it: \(errorDescription ?? "unknown")"); return }
            
            self.load()
        }
    }
    
    @objc func addToMap(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let keyset = keysets[int]
        
        if keyset.sharedWith != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                var alertStyle = UIAlertController.Style.actionSheet
                if (UIDevice.current.userInterfaceIdiom == .pad) {
                  alertStyle = UIAlertController.Style.alert
                }
                
                let alert = UIAlertController(title: "Cosigner already shared!", message: "This cosigner was previously added to an Account, reusing keys is never a good idea. Are you sure you want to share this cosigner again?", preferredStyle: alertStyle)
                
                alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
                    self.promptToSelectMap(keyset, int)
                }))
                                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            promptToSelectMap(keyset, int)
        }
    }
    
    private func promptToSelectMap(_ keyset: KeysetStruct, _ section: Int) {
        CoreDataService.retrieveEntity(entityName: .accountMap) { [weak self] (accountMaps, errorDescription) in
            guard let self = self else { return }
            
            guard let accountMaps = accountMaps, accountMaps.count > 0 else {
                showAlert(self, "No Accounts exist yet", "Create one first.")
                return
            }
            
            var policyMaps = [AccountMapStruct]()
            
            for (a, accountMap) in accountMaps.enumerated() {
                let mapStruct = AccountMapStruct(dictionary: accountMap)
                
                if mapStruct.descriptor.contains("keyset") {
                    policyMaps.append(mapStruct)
                }
                
                if a + 1 == accountMaps.count {
                    guard policyMaps.count > 0 else {
                        showAlert(self, "No incomplete Accounts", "All of your Accounts are complete, create a new one to add cosigners")
                        return
                    }
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        var alertStyle = UIAlertController.Style.actionSheet
                        if (UIDevice.current.userInterfaceIdiom == .pad) {
                          alertStyle = UIAlertController.Style.alert
                        }
                        
                        let alert = UIAlertController(title: "Which Account?", message: "Select the Account you want this cosigner to join.", preferredStyle: alertStyle)
                        
                        for policyMap in policyMaps {
                            alert.addAction(UIAlertAction(title: policyMap.label, style: .default, handler: { action in
                                self.updateAccountMap(policyMap, keyset, section)
                            }))
                        }
                                        
                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                        alert.popoverPresentationController?.sourceView = self.view
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    private func updateAccountMap(_ accountMap: AccountMapStruct, _ keyset: KeysetStruct, _ section: Int) {
        var desc = accountMap.descriptor
        let descriptorParser = DescriptorParser()
        let descStruct = descriptorParser.descriptor(desc)
        var mofn = descStruct.mOfNType
        mofn = mofn.replacingOccurrences(of: " of ", with: "*")
        let arr = mofn.split(separator: "*")
        guard let n = Int(arr[1]) else { return }
        
        for i in 0...n - 1 {
            if desc.contains("<keyset #\(i + 1)>") {
                desc = desc.replacingOccurrences(of: "<keyset #\(i + 1)>", with: keyset.bip48SegwitAccount!)
                break
            }
        }
        
        guard var dict = try? JSONSerialization.jsonObject(with: accountMap.accountMap, options: []) as? [String:Any] else { return }
        dict["descriptor"] = desc
        
        let updatedMap = (dict.json() ?? "").utf8
        
        CoreDataService.updateEntity(id: accountMap.id, keyToUpdate: "descriptor", newValue: desc, entityName: .accountMap) { (success, errorDesc) in
            guard success else {
                showAlert(self, "Account Map updating failed...", "Please let us know about this bug.")
                return
            }
            
            CoreDataService.updateEntity(id: accountMap.id, keyToUpdate: "accountMap", newValue: updatedMap, entityName: .accountMap) { (success, errorDesc) in
                guard success else {
                    showAlert(self, "Account Map updating failed...", "Please let us know about this bug.")
                    return
                }
                
                CoreDataService.updateEntity(id: keyset.id, keyToUpdate: "sharedWith", newValue: accountMap.id, entityName: .keyset) { (success, errorDescription) in
                    guard success else {
                        showAlert(self, "Account Map updating failed...", "Please let us know about this bug.")
                        return
                    }
                    
                    CoreDataService.updateEntity(id: keyset.id, keyToUpdate: "dateShared", newValue: Date(), entityName: .keyset) { (success, errorDescription) in
                        guard success else {
                            showAlert(self, "Account Map updating failed...", "Please let us know about this bug.")
                            return
                        }
                        
                        showAlert(self, "Account Map updated ✓", "")
                        
                        self.refresh(section)
                    }
                }
            }
        }
    }
    
    @objc func exportMultisigKeyset(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let keyset = keysets[int]
        guard let account = keyset.bip48SegwitAccount else { return }
        
        keysetToExport = account
        headerText = "Multi-sig keyset"
        subheaderText = account
        export()
    }
    
    private func export() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "exportKeyset", sender: self)
        }
    }
    
    @objc func deleteKeyset(_ id: UUID, _ section: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            
            let alert = UIAlertController(title: "Delete cosigner?", message: "", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
                self.deleteKeysetNow(id, section)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func deleteKeysetNow(_ id: UUID, _ section: Int) {
        CoreDataService.deleteEntity(id: id, entityName: .keyset) { (success, errorDescription) in
            guard success else {
                showAlert(self, "Error deleting signer", "We were unable to delete that cosigner!")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.lifehashes.remove(at: section)
                self?.keysets.remove(at: section)
                self?.keysetsTable.deleteSections(IndexSet.init(arrayLiteral: section), with: .fade)
            }
            
            showAlert(self, "", "Cosigner deleted ✓")
        }
    }
    
    @objc func editKeysets() {
        keysetsTable.setEditing(!keysetsTable.isEditing, animated: true)
        
        if keysetsTable.isEditing {
            editButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(editKeysets))
        } else {
            editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editKeysets))
        }
        
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
    }
    
    private func addKeyset(_ account: String) {
        let hack = "wsh(\(account)/0/*)"
        let dp = DescriptorParser()
        let ds = dp.descriptor(hack)
        
        var keyset = [String:Any]()
        keyset["id"] = UUID()
        keyset["label"] = "keyset"
        keyset["bip48SegwitAccount"] = account
        keyset["dateAdded"] = Date()
        keyset["fingerprint"] = ds.fingerprint
        
        CoreDataService.saveEntity(dict: keyset, entityName: .keyset) { [weak self] (success, errorDesc) in
            guard let self = self else { return }
            
            guard success else {
                showAlert(self, "Cosigner not saved!", "Please let us know about this bug.")
                return
            }
            
            DispatchQueue.main.async {
                self.keysetsTable.reloadData()
                
                var alertStyle = UIAlertController.Style.actionSheet
                if (UIDevice.current.userInterfaceIdiom == .pad) {
                  alertStyle = UIAlertController.Style.alert
                }
                
                let alert = UIAlertController(title: "Cosigner imported ✓", message: "Would you like to give it a label now? You can edit the label at any time.", preferredStyle: alertStyle)
                
                alert.addAction(UIAlertAction(title: "Add label", style: .default, handler: { action in
                    self.promptToEditLabel(KeysetStruct(dictionary: keyset))
                }))
                                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                    self.load()
                }))
                
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "exportKeyset" {
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.text = keysetToExport
                vc.isPsbt = false
                vc.descriptionText = subheaderText
                vc.header = headerText
            }
        }
        
        if segue.identifier == "segueToScanKeyset" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.doneBlock = { [weak self] result in
                    guard let self = self, let result = result else { return }
                    
                    if let account = URHelper.accountUr(result) {
                        self.addKeyset(account)
                    } else if result.contains("48h/0h/0h/2h") {
                        self.addKeyset(result)
                    } else {
                        showAlert(self, "Cosigner not recognized!", "Currently Gordian Cosigner only supports native segwit multisig derivations.")
                    }
                }
            }
        }
    }
}
