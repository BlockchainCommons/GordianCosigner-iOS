//
//  PsbtViewController.swift
//  GordianSigner
//
//  Created by Peter on 11/17/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit
import LibWally
import URKit

class PsbtViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private let spinner = Spinner()
    private var psbts = [PsbtStruct]()
    private var psbtText = ""
    private var lifeHashes = [UIImage]()
    private var completes = [Bool]()
    private var amounts = [Double]()
    private var weSigned = [Bool]()
    private var psbtToExport = ""
    var addButton = UIBarButtonItem()
    var editButton = UIBarButtonItem()
    @IBOutlet weak private var psbtTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        psbtTable.delegate = self
        psbtTable.dataSource = self
        
        addButton = UIBarButtonItem.init(barButtonSystemItem: .add, target: self, action: #selector(add))
        editButton = UIBarButtonItem.init(barButtonSystemItem: .edit, target: self, action: #selector(editPsbts))
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
        
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .psbtSaved, object: nil)
        spinner.add(vc: self, description: "loading...")
        load()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if UserDefaults.standard.object(forKey: "seenPaymentInfo") == nil {
            showInfo()
            UserDefaults.standard.set(true, forKey: "seenPaymentInfo")
        }
    }
    
    @objc func reload() {
        refresh()
    }
    
    private func refresh() {
        spinner.add(vc: self, description: "refreshing...")
        load()
    }
    
    @objc func add() {
        segueToAdd()
    }
    
    private func load() {
        psbts.removeAll()
        completes.removeAll()
        lifeHashes.removeAll()
        amounts.removeAll()
        weSigned.removeAll()
        
        CoreDataService.retrieveEntity(entityName: .payment) { [weak self] (psbts, errorDescription) in
            guard let self = self else { return }
            
            guard let psbts = psbts, psbts.count > 0 else {
                self.spinner.remove()
                return
            }
            
            DispatchQueue.background(background: {
                
                for (p, psbt) in psbts.enumerated() {
                    let psbtStruct = PsbtStruct(dictionary: psbt)
                    self.psbts.append(psbtStruct)
                                        
                    if let psbtWally = Keys.psbt(psbtStruct.psbt) {
                        guard let image = LifeHash.image(PaymentId.id(psbtWally).utf8) else { self.spinner.remove(); return }
                        
                        var amount = 0.0
                        self.weSigned.append(false)
                        
                        for input in psbtWally.inputs {
                            if let inputAmount = input.amount {
                                amount += Double(inputAmount) / 100000000.0
                            }
                            
                            if let origins = input.origins {
                                for origin in origins {
                                    let originalPubkey = origin.key.data.hexString
                                    CoreDataService.retrieveEntity(entityName: .cosigner) { (cosigners, errorDescription) in
                                        if let cosigners = cosigners, cosigners.count > 0 {

                                            for cosigner in cosigners {
                                                let cosignerStruct = CosignerStruct(dictionary: cosigner)
                                                if let encryptedXprv = cosignerStruct.xprv {
                                                    if let decryptedXprv = Encryption.decrypt(encryptedXprv) {
                                                        if let hdkey = try? HDKey(base58: decryptedXprv.utf8) {
                                                            if let accountPath = try? origin.value.path.chop(depth: 4) {
                                                                if let childKey = try? hdkey.derive(using: accountPath) {
                                                                    if childKey.pubKey.data.hexString == originalPubkey {
                                                                        if let sigs = input.signatures {
                                                                            for sig in sigs {
                                                                                if sig.key.data.hexString == originalPubkey {
                                                                                    // DID SIGN
                                                                                    self.weSigned[p] = true
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        self.amounts.append(amount)
                        
                        if let finalized = try? psbtWally.finalized() {
                            self.completes.append(finalized.isComplete)
                        } else {
                            self.completes.append(psbtWally.isComplete)
                        }
                        
                        self.lifeHashes.append(image)
                    } else {
                        showAlert(self, "", "There was an issue converting your psbt.")
                    }
                }
                
            }, completion: { [weak self] in
                guard let self = self else { return }
                
                self.psbtTable.reloadData()
                self.spinner.remove()
            })
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if psbts.count == 0 {
            return 1
        } else {
            return psbts.count
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if psbts.count > 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "psbtCell", for: indexPath)
            configureCell(cell)
            let psbt = psbts[indexPath.section]
            
            let detailButton = cell.viewWithTag(3) as! UIButton
            detailButton.addTarget(self, action: #selector(seeDetail(_:)), for: .touchUpInside)
            detailButton.restorationIdentifier = "\(indexPath.section)"
            
            let dateAdded = cell.viewWithTag(6) as! UILabel
            dateAdded.text = psbt.dateAdded.formatted()
            
            let lifehash = cell.viewWithTag(7) as! LifehashSeedView
            lifehash.backgroundColor = cell.backgroundColor
            lifehash.background.backgroundColor = cell.backgroundColor
            lifehash.lifehashImage.image = lifeHashes[indexPath.section]
            lifehash.iconLabel.text = psbt.label
            lifehash.iconImage.image = UIImage(systemName: "bitcoinsign.circle")
            
            let editButton = cell.viewWithTag(8) as! UIButton
            editButton.addTarget(self, action: #selector(editLabel(_:)), for: .touchUpInside)
            editButton.restorationIdentifier = "\(indexPath.section)"
            
            let complete = cell.viewWithTag(9) as! UILabel
            let completeIcon = cell.viewWithTag(10) as! UIImageView
            if completes[indexPath.section] {
                complete.text = "fully signed"
                completeIcon.image = UIImage(systemName: "checkmark.circle")
                complete.textColor = .systemGreen
                completeIcon.tintColor = .systemGreen
            } else {
                complete.text = "requires signature"
                completeIcon.image = UIImage(systemName: "exclamationmark.triangle")
                complete.textColor = .systemOrange
                completeIcon.tintColor = .systemOrange
            }
            
            let amountLabel = cell.viewWithTag(11) as! UILabel
            amountLabel.text = amounts[indexPath.section].avoidNotation
            
            let signedByUsImageView = cell.viewWithTag(12) as! UIImageView
            let signedByUsLabel = cell.viewWithTag(13) as! UILabel
            if weSigned[indexPath.section] {
                signedByUsImageView.tintColor = .systemGreen
                signedByUsLabel.text = "Signed by us ✓"
                signedByUsLabel.textColor = .systemGreen
            } else {
                signedByUsImageView.tintColor = .systemRed
                signedByUsLabel.text = "We have not signed ｘ"
                signedByUsLabel.textColor = .systemRed
            }
            
            return cell
        } else {
            let defaultCell = tableView.dequeueReusableCell(withIdentifier: "psbtDefaultCell", for: indexPath)
            let button = defaultCell.viewWithTag(1) as! UIButton
            button.addTarget(self, action: #selector(add), for: .touchUpInside)
            return defaultCell
        }
     }
    
    @objc func exportQr(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        psbtToExport = psbts[int].psbt.base64EncodedString()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToShowPsbtQR", sender: self)
        }
        
    }
    
    @objc func exportAsFile(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
                
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
                        
            let fileManager = FileManager.default
            let fileURL = fileManager.temporaryDirectory.appendingPathComponent("Gordian.psbt")
            
            try? self.psbts[int].psbt.write(to: fileURL)
            
            let controller = UIDocumentPickerViewController(url: fileURL, in: .exportToService)
            self.present(controller, animated: true)
        }
    }
    
    @objc func copyText(_ sender: UIButton) {
         guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            UIPasteboard.general.string = self.psbts[int].psbt.base64EncodedString()
            showAlert(self, "Copied ✓", "")
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if psbts.count > 0 {
            return 196
        } else {
            return 44
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let psbt = psbts[indexPath.section]
            deletePsbt(psbt.id, indexPath.section)
        }
    }
    
    private func configureCell(_ cell: UITableViewCell) {
        cell.selectionStyle = .none
        cell.layer.cornerRadius = 8
        cell.layer.borderColor = UIColor.darkGray.cgColor
        cell.layer.borderWidth = 0.5
    }
    
    private func configureView(_ view: UIView) {
        view.clipsToBounds = true
        view.layer.cornerRadius = 8
    }
    
    @objc func editLabel(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let psbt = psbts[int]
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Edit psbt label"
            let message = ""
            let style = UIAlertController.Style.alert
            let alert = UIAlertController(title: title, message: message, preferredStyle: style)
            
            let save = UIAlertAction(title: "Save", style: .default) { [weak self] (alertAction) in
                guard let self = self else { return }
                
                let textField1 = (alert.textFields![0] as UITextField).text
                
                guard let updatedLabel = textField1, updatedLabel != "" else { return }
                
                self.updateLabel(psbt.id, updatedLabel)
            }
            
            alert.addTextField { (textField) in
                textField.text = psbt.label
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
        CoreDataService.updateEntity(id: id, keyToUpdate: "label", newValue: label, entityName: .payment) { (success, errorDescription) in
            guard success else {
                showAlert(self, "Label not saved!", "There was an error updating your label, please let us know about it: \(errorDescription ?? "unknown")")
                return
            }
            
            self.refresh()
        }
    }
    
    private func segueToAdd() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "addPsbtSegue", sender: self)
        }
    }
    
    @objc func seeDetail(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        psbtText = psbts[int].psbt.base64EncodedString()
        segueToDetail()
    }
    
    private func segueToDetail() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToPsbtDetail", sender: self)
        }
    }
    
    @objc func editPsbts() {
        if psbts.count > 0 {
            psbtTable.setEditing(!psbtTable.isEditing, animated: true)
        } else {
            psbtTable.setEditing(false, animated: true)
        }
        
        if psbtTable.isEditing {
            editButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(editPsbts))
        } else {
            editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editPsbts))
        }
        
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
    }
    
    @objc func deletePsbt(_ id: UUID, _ section: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            
            let alert = UIAlertController(title: "Delete psbt?", message: "", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
                self.deletePsbtNow(id, section)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func deletePsbtNow(_ id: UUID, _ section: Int) {
        CoreDataService.deleteEntity(id: id, entityName: .payment) { (success, errorDescription) in
            guard success else {
                showAlert(self, "Error deleting psbt", "")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.amounts.remove(at: section)
                self?.psbts.remove(at: section)
                self?.lifeHashes.remove(at: section)
                self?.completes.remove(at: section)
                self?.weSigned.remove(at: section)
                if self?.psbts.count ?? 0 > 0 {
                    self?.psbtTable.deleteSections(IndexSet.init(arrayLiteral: section), with: .fade)
                } else {
                    self?.editPsbts()
                    self?.psbtTable.reloadData()
                }
            }
        }
    }
    
    @IBAction func infoAction(_ sender: Any) {
        showInfo()
    }
    
    private func showInfo() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToPaymentsInfo", sender: self)
        }
    }

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToPsbtDetail" {
            if let vc = segue.destination as? PsbtTableViewController {
                vc.psbtText = psbtText
            }
        }
        
        if segue.identifier == "segueToShowPsbtQR" {
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.isPsbt = true
                vc.text = psbtToExport
            }
        }
        
        if segue.identifier == "segueToPaymentsInfo" {
            if let vc = segue.destination as? InfoViewController {
                vc.isPayment = true
            }
        }
    }
    

}
