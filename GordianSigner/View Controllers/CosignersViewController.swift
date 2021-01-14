//
//  KeysetsViewController.swift
//  GordianSigner
//
//  Created by Peter on 11/15/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit
import LibWally

class KeysetsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var addButton = UIBarButtonItem()
    var editButton = UIBarButtonItem()
    private var cosigners = [CosignerStruct]()
    private var accounts = [AccountStruct]()
    private var cosignerToExport = ""
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
        editButton = UIBarButtonItem.init(barButtonSystemItem: .edit, target: self, action: #selector(editCosigners))
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshTable), name: .cosignerAdded, object: nil)
        load()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if UserDefaults.standard.object(forKey: "seenCosignerInfo") == nil {
            showInfo()
            UserDefaults.standard.set(true, forKey: "seenCosignerInfo")
        }
    }
    
    @IBAction func infoAction(_ sender: Any) {
        showInfo()
    }
    
    private func addSeedWords() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToAddSeedWords", sender: self)
        }
    }
    
    private func seeSeedWords() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToSeeSeedDetail", sender: self)
        }
    }
    
    private func getPasteboard() {
        if let pasteBoard = UIPasteboard.general.string {
            if let account = URHelper.accountUr(pasteBoard) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    var alertStyle = UIAlertController.Style.actionSheet
                    if (UIDevice.current.userInterfaceIdiom == .pad) {
                        alertStyle = UIAlertController.Style.alert
                    }
                    
                    let alert = UIAlertController(title: "Import cosigner?", message: "You have a valid cosigner on your clipboard, would you like to import it?", preferredStyle: alertStyle)
                    
                    alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
                        self.addKeyset(account)
                    }))
                    
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                    alert.popoverPresentationController?.sourceView = self.view
                    self.present(alert, animated: true, completion: nil)
                }
            } else if pasteBoard.contains("48h/\(Keys.coinType)h/0h/2h") || pasteBoard.contains("48'/\(Keys.coinType)'/0'/2'") {
                self.addKeyset(pasteBoard)
            } else {
                showAlert(self, "", "Invalid cosigner text, we accept UR crypto-account or [<fingerprint>/48h/\(Keys.coinType)h/0h/2h]xpub.....")
            }
        } else {
            showAlert(self, "Invalid cosigner text", "We accept UR crypto-account or [<fingerprint>/48h/\(Keys.coinType)h/0h/2h]xpub.....")
        }
    }
    
    @objc func add() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
                alertStyle = UIAlertController.Style.alert
            }
            
            let alert = UIAlertController(title: "Add Cosigner", message: "You may either create or import a cosigner.", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { action in
                self.addSeedWords()
            }))
            
            alert.addAction(UIAlertAction(title: "Import", style: .default, handler: { action in
                self.importCosigner()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func importCosigner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
                alertStyle = UIAlertController.Style.alert
            }
            
            let alert = UIAlertController(title: "Import Cosigner", message: "You may either paste one as text or scan a QR code.", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Paste", style: .default, handler: { action in
                self.getPasteboard()
            }))
            
            alert.addAction(UIAlertAction(title: "Scan QR", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.performSegue(withIdentifier: "segueToScanKeyset", sender: self)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @objc func refreshTable() {
        load()
    }
    
    private func load() {
        spinner.add(vc: self, description: "loading...")
        cosigners.removeAll()
        lifehashes.removeAll()
        accounts.removeAll()
        
        CoreDataService.retrieveEntity(entityName: .account) { (accounts, err) in
            if let accounts = accounts {
                for account in accounts {
                    self.accounts.append(AccountStruct(dictionary: account))
                }
            }
        }
        
        CoreDataService.retrieveEntity(entityName: .cosigner) { [weak self] (cosigners, errorDescription) in
            guard let self = self else { return }
            
            guard let cosigners = cosigners, cosigners.count > 0 else { self.spinner.remove(); return }
            
            DispatchQueue.background(background: { [weak self] in
                guard let self = self else { return }
                for (i, cosigner) in cosigners.enumerated() {
                    let cosignerStruct = CosignerStruct(dictionary: cosigner)
                    self.cosigners.append(cosignerStruct)
                    self.lifehashes.append(LifeHash.image(cosignerStruct.lifehash) ?? UIImage())
                    
                    if i + 1 == cosigners.count {
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
    
    private func refresh(_ section: Int) {
        spinner.add(vc: self, description: "")
        cosigners.removeAll()
        
        CoreDataService.retrieveEntity(entityName: .cosigner) { [weak self] (cosigners, errorDescription) in
            guard let self = self else { return }
            
            guard let cosigners = cosigners, cosigners.count > 0 else { self.spinner.remove(); return }
            
            for (i, cosigner) in cosigners.enumerated() {
                let cosignerStruct = CosignerStruct(dictionary: cosigner)
                self.cosigners.append(cosignerStruct)
                
                if i + 1 == cosigners.count {
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
        if cosigners.count > 0 {
            return cosigners.count
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if cosigners.count > 0 {
        let cell = tableView.dequeueReusableCell(withIdentifier: "keysetCell", for: indexPath)
        configureCell(cell)
        
        if cosigners.count > 0 && indexPath.section < cosigners.count && lifehashes.count > 0 && indexPath.section < lifehashes.count {
            let cosigner = cosigners[indexPath.section]
            
            let fingerprintLabel = cell.viewWithTag(2) as! UILabel
            if let key = cosigner.bip48SegwitAccount {
                let arr = key.split(separator: "]")
                fingerprintLabel.text = "\(String(describing: arr[0]))]"
            } else {
                fingerprintLabel.text = cosigner.fingerprint
            }
            
            let dateAddedLabel = cell.viewWithTag(7) as! UILabel
            dateAddedLabel.text = cosigner.dateAdded.formatted()

            let exportKeysetButton = cell.viewWithTag(9) as! UIButton
            exportKeysetButton.restorationIdentifier = "\(indexPath.section)"
            configureView(exportKeysetButton)
            exportKeysetButton.addTarget(self, action: #selector(exportCosigner(_:)), for: .touchUpInside)
            
            let isSharedImage = cell.viewWithTag(5) as! UIImageView
            let sharedText = cell.viewWithTag(14) as! UILabel
            if cosigner.sharedWith != nil {
                isSharedImage.image = UIImage(systemName: "person.2.square.stack")
                isSharedImage.tintColor = .systemPink
                sharedText.textColor = .systemPink
                for account in accounts {
                    if account.id == cosigner.sharedWith {
                        sharedText.text = account.label
                    }
                }
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
            
            let keysetLifehash = cell.viewWithTag(16) as! LifehashSeedView
            keysetLifehash.backgroundColor = cell.backgroundColor
            keysetLifehash.background.backgroundColor = cell.backgroundColor
            keysetLifehash.lifehashImage.image = UIImage(data: cosigner.lifehash)
            keysetLifehash.iconImage.image = UIImage(systemName: "person.2")
            keysetLifehash.iconLabel.text = cosigner.label
            
            return cell
        } else {
            return UITableViewCell()
        }
            
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cosignerDefaultCell", for: indexPath)
            let button = cell.viewWithTag(1) as! UIButton
            button.addTarget(self, action: #selector(add), for: .touchUpInside)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if cosigners.count > 0 {
            return 170
        } else {
            return 44
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let keyset = cosigners[indexPath.section]
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
    
    @objc func copyText(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let keyset = cosigners[int]
        
        UIPasteboard.general.string = keyset.bip48SegwitAccount
        showAlert(self, "", "Cosigner text copied ✓")
    }
    
    @objc func editLabel(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let keyset = cosigners[int]
        
        promptToEditLabel(keyset)
    }
    
    private func promptToEditLabel(_ keyset: CosignerStruct) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Edit cosigner label"
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
        CoreDataService.updateEntity(id: id, keyToUpdate: "label", newValue: label, entityName: .cosigner) { (success, errorDescription) in
            guard success else { showAlert(self, "Label not saved!", "There was an error updating your label, please let us know about it: \(errorDescription ?? "unknown")"); return }
            
            self.load()
        }
    }
    
    @objc func exportCosigner(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let keyset = cosigners[int]
        guard let account = keyset.bip48SegwitAccount else { return }
        
        cosignerToExport = account
        headerText = "Cosigner"
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
                self.deleteCosignerNow(id, section)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func deleteCosignerNow(_ id: UUID, _ section: Int) {
        CoreDataService.deleteEntity(id: id, entityName: .cosigner) { (success, errorDescription) in
            guard success else {
                showAlert(self, "Error deleting cosigner", "We were unable to delete that cosigner!")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.lifehashes.remove(at: section)
                self?.cosigners.remove(at: section)
                if self?.cosigners.count ?? 0 > 0 {
                    self?.keysetsTable.deleteSections(IndexSet.init(arrayLiteral: section), with: .fade)
                } else {
                    self?.editCosigners()
                    self?.keysetsTable.reloadData()
                }
                
            }            
        }
    }
    
    @objc func editCosigners() {
        if cosigners.count > 0 {
            keysetsTable.setEditing(!keysetsTable.isEditing, animated: true)
        } else {
            keysetsTable.setEditing(false, animated: true)
        }
        
        if keysetsTable.isEditing {
            editButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(editCosigners))
        } else {
            editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editCosigners))
        }
        
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
    }
    
    private func addKeyset(_ account: String) {
        let hack = "wsh(\(account)/0/*)"
        let dp = DescriptorParser()
        let ds = dp.descriptor(hack)
                
        guard let _ = try? HDKey(base58: ds.accountXpub) else {
            showAlert(self, "Invalid key", "Gordian Cosigner is not yet compatible with slip132, please ensure you are adding a valid xpub and try again.")
            return
        }
        
        guard account.contains("/48h/\(Keys.coinType)h/0h/2h") || account.contains("/48'/\(Keys.coinType)'/0'/2'") else {
            showAlert(self, "Unsupported Cosigner", "Gordian Cosigner currently only supports the m/48h/\(Keys.coinType)h/0h/2h key origin.")
            return
        }
        
        var keyset = [String:Any]()
        keyset["id"] = UUID()
        keyset["label"] = "Cosigner"
        keyset["bip48SegwitAccount"] = account
        keyset["dateAdded"] = Date()
        keyset["fingerprint"] = ds.fingerprint
        
        CoreDataService.saveEntity(dict: keyset, entityName: .cosigner) { [weak self] (success, errorDesc) in
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
                    self.promptToEditLabel(CosignerStruct(dictionary: keyset))
                }))
                                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                    self.load()
                }))
                
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func showInfo() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToCosignersInfo", sender: self)
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "exportKeyset" {
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.text = cosignerToExport
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
                    } else if result.contains("48h/\(Keys.coinType)h/0h/2h") || result.contains("48'/\(Keys.coinType)'/0'/2'") {
                        self.addKeyset(result)
                    } else {
                        showAlert(self, "Cosigner not recognized!", "Gordian Cosigner currently only supports the m/48h/\(Keys.coinType)h/0h/2h key origin.")
                    }
                }
            }
        }
        
        if segue.identifier == "segueToCosignersInfo" {
            if let vc = segue.destination as? InfoViewController {
                vc.isCosigner = true
            }
        }
        
        if segue.identifier == "segueToAddSeedWords" {
            if let vc = segue.destination as? AddSignerViewController {
                vc.doneBlock = {
                    self.load()
                }
            }
        }
    }
}
