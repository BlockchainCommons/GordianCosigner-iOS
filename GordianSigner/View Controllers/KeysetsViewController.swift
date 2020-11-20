//
//  KeysetsViewController.swift
//  GordianSigner
//
//  Created by Peter on 11/15/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class KeysetsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var editButton = UIBarButtonItem()
    private var keysets = [KeysetStruct]()
    private var signers = [SignerStruct]()
    private var keysetToExport = ""
    private var headerText = ""
    private var subheaderText = ""

    @IBOutlet weak private var keysetsTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        keysetsTable.delegate = self
        keysetsTable.dataSource = self
        
        editButton.tintColor = .systemTeal
        editButton = UIBarButtonItem.init(barButtonSystemItem: .edit, target: self, action: #selector(editKeysets))
        self.navigationItem.setRightBarButtonItems([editButton], animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        load()
    }
    
    private func load() {
        getSigners()
        
        keysets.removeAll()
        
        CoreDataService.retrieveEntity(entityName: .keyset) { [weak self] (keysets, errorDescription) in
            guard let self = self else { return }
            
            guard let keysets = keysets, keysets.count > 0 else { return }
            
            for (i, keyset) in keysets.enumerated() {
                let keysetStruct = KeysetStruct(dictionary: keyset)
                self.keysets.append(keysetStruct)
                
                if i + 1 == keysets.count {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.keysetsTable.reloadData()
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
        
        let keyset = keysets[indexPath.section]
        
        let label = cell.viewWithTag(1) as! UILabel
        label.text = keyset.label
        
        let fingerprintLabel = cell.viewWithTag(2) as! UILabel
        fingerprintLabel.text = keyset.fingerprint
        
        let (isHot, isMine, lifeHash) = canSign(keyset)
        
        let isHotImage = cell.viewWithTag(3) as! UIImageView
        if isHot {
            isHotImage.alpha = 1
        } else {
            isHotImage.alpha = 0
        }
        
        let isMineImage = cell.viewWithTag(4) as! UIImageView
        if isMine {
            isMineImage.image = UIImage(systemName: "person.crop.circle.fill.badge.checkmark")
            isMineImage.tintColor = .systemGreen
        } else {
            isMineImage.image = UIImage(systemName: "person.crop.circle.fill.badge.xmark")
            isMineImage.tintColor = .systemOrange
        }
        
        let lifeHashImage = cell.viewWithTag(6) as! UIImageView
        configureView(lifeHashImage)
        if lifeHash != nil {
            lifeHashImage.image = lifeHash
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
        if keyset.sharedWith != nil {
            isSharedImage.image = UIImage(systemName: "person.2")
            isSharedImage.tintColor = .systemPink
        } else {
            isSharedImage.image = UIImage(systemName: "person")
            isSharedImage.tintColor = .systemBlue
        }
        
        let editButton = cell.viewWithTag(12) as! UIButton
        editButton.addTarget(self, action: #selector(editLabel(_:)), for: .touchUpInside)
        editButton.restorationIdentifier = "\(indexPath.section)"
        
        let textView = cell.viewWithTag(13) as! UITextView
        textView.text = keyset.bip48SegwitAccount ?? ""
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 319
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let keyset = keysets[indexPath.section]
            deleteKeyset(keyset.id, indexPath.section)
        }
    }
    
    private func configureCell(_ cell: UITableViewCell) {
        cell.selectionStyle = .none
    }
    
    private func configureView(_ view: UIView) {
        view.clipsToBounds = true
        view.layer.cornerRadius = 8
    }
    
    private func getSigners() {
        self.signers.removeAll()
        
        CoreDataService.retrieveEntity(entityName: .signer) { (signers, errorDescription) in
            guard let signers = signers, signers.count > 0 else { return }
            
            for signer in signers {
                self.signers.append(SignerStruct(dictionary: signer))
            }
        }
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
    
    @objc func editLabel(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let keyset = keysets[int]
        
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
                textField.placeholder = "new label"
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
        guard let account = keyset.bip48SegwitAccount else { return }
        
        promptToSelectMap(account)
    }
    
    private func promptToSelectMap(_ keyset: String) {
        CoreDataService.retrieveEntity(entityName: .accountMap) { [weak self] (accountMaps, errorDescription) in
            guard let self = self else { return }
            
            guard let accountMaps = accountMaps, accountMaps.count > 0 else {
                showAlert(self, "No Account Maps exist yet", "Create one first.")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                var alertStyle = UIAlertController.Style.actionSheet
                if (UIDevice.current.userInterfaceIdiom == .pad) {
                  alertStyle = UIAlertController.Style.alert
                }
                
                let alert = UIAlertController(title: "Which Account Map?", message: "Select the Account Map you want this keyset to join.", preferredStyle: alertStyle)
                
                for accountMap in accountMaps {
                    let mapStruct = AccountMapStruct(dictionary: accountMap)
                    
                    if mapStruct.descriptor.contains("keystore") {
                        alert.addAction(UIAlertAction(title: mapStruct.label, style: .default, handler: { action in
                            self.updateAccountMap(mapStruct, keyset: keyset)
                        }))
                    }
                }
                                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func updateAccountMap(_ accountMap: AccountMapStruct, keyset: String) {
        var desc = accountMap.descriptor
        let descriptorParser = DescriptorParser()
        let descStruct = descriptorParser.descriptor(desc)
        var mofn = descStruct.mOfNType
        mofn = mofn.replacingOccurrences(of: " of ", with: "*")
        let arr = mofn.split(separator: "*")
        guard let n = Int(arr[1]) else { return }
        
        for i in 0...n - 1 {
            if desc.contains("<keystore #\(i + 1)>") {
                desc = desc.replacingOccurrences(of: "<keystore #\(i + 1)>", with: keyset)
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
                
                showAlert(self, "Account Map updated ✓", "")
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
            
            let alert = UIAlertController(title: "Delete keyset?", message: "", preferredStyle: alertStyle)
            
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
                showAlert(self, "Error deleting signer", "We were unable to delete that signer!")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.keysets.remove(at: section)
                self?.keysetsTable.deleteSections(IndexSet.init(arrayLiteral: section), with: .fade)
            }
            
            showAlert(self, "Keyset deleted ✅", "")
        }
    }
    
    @objc func editKeysets() {
        keysetsTable.setEditing(!keysetsTable.isEditing, animated: true)
        
        if keysetsTable.isEditing {
            editButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(editKeysets))
        } else {
            editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editKeysets))
        }
        
        self.navigationItem.setRightBarButtonItems([editButton], animated: true)
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
    }

}
