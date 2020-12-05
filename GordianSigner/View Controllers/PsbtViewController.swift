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
    
    @objc func reload() {
        refresh()
    }
    
    private func refresh() {
        spinner.add(vc: self, description: "refreshing...")
        psbts.removeAll()
        completes.removeAll()
        lifeHashes.removeAll()
        amounts.removeAll()
        load()
    }
    
    @objc func add() {
        segueToAdd()
    }
    
    private func load() {
        CoreDataService.retrieveEntity(entityName: .psbt) { [weak self] (psbts, errorDescription) in
            guard let self = self else { return }
            
            guard let psbts = psbts, psbts.count > 0 else { self.spinner.remove(); return }
            
            DispatchQueue.background(background: {
                
                for psbt in psbts {
                    let psbtStruct = PsbtStruct(dictionary: psbt)
                    self.psbts.append(psbtStruct)
                    
                    guard let image = LifeHash.image(psbtStruct.psbt) else { self.spinner.remove(); return }
                                        
                    guard let psbtWally = Keys.psbt(psbtStruct.psbt.base64EncodedString(), .mainnet) else { self.spinner.remove(); return }
                    
                    var amount = 0.0
                    for input in psbtWally.inputs {
                        if let inputAmount = input.amount {
                            amount += Double(inputAmount) / 100000000.0
                        }
                    }
                    
                    self.amounts.append(amount)
                    
                    if let finalized = try? psbtWally.finalized() {
                        self.completes.append(finalized.isComplete)
                    } else {
                        self.completes.append(psbtWally.isComplete)
                    }
                    
                    self.lifeHashes.append(image)
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
        if lifeHashes.count > 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "psbtCell", for: indexPath)
            configureCell(cell)
            let psbt = psbts[indexPath.section]
            
            let copyTextButton = cell.viewWithTag(1) as! UIButton
            copyTextButton.restorationIdentifier = "\(indexPath.section)"
            copyTextButton.addTarget(self, action: #selector(copyText(_:)), for: .touchUpInside)
            
            let exportFileButton = cell.viewWithTag(2) as! UIButton
            exportFileButton.restorationIdentifier = "\(indexPath.section)"
            exportFileButton.addTarget(self, action: #selector(exportAsFile(_:)), for: .touchUpInside)
            
            let detailButton = cell.viewWithTag(3) as! UIButton
            detailButton.addTarget(self, action: #selector(seeDetail(_:)), for: .touchUpInside)
            detailButton.restorationIdentifier = "\(indexPath.section)"
            
            let exportQrButton = cell.viewWithTag(4) as! UIButton
            exportQrButton.restorationIdentifier = "\(indexPath.section)"
            exportQrButton.addTarget(self, action: #selector(exportQr(_:)), for: .touchUpInside)
            
            let label = cell.viewWithTag(5) as! UILabel
            label.text = psbt.label
            
            let dateAdded = cell.viewWithTag(6) as! UILabel
            dateAdded.text = psbt.dateAdded.formatted()
            
            let lifehash = cell.viewWithTag(7) as! UIImageView
            configureView(lifehash)
            lifehash.contentMode = .scaleAspectFit
            lifehash.image = lifeHashes[indexPath.section]
            
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
            
            return cell
        } else {
            let defaultCell = UITableViewCell()
            defaultCell.textLabel?.text = "No payments added yet, use Gordian Wallet to create an unsigned payment and add it here."
            defaultCell.textLabel?.textColor = .lightGray
            defaultCell.textLabel?.numberOfLines = 0
            defaultCell.sizeToFit()
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
            return 228
        } else {
            return 100
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
        CoreDataService.updateEntity(id: id, keyToUpdate: "label", newValue: label, entityName: .psbt) { (success, errorDescription) in
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
        psbtTable.setEditing(!psbtTable.isEditing, animated: true)
        
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
        CoreDataService.deleteEntity(id: id, entityName: .psbt) { (success, errorDescription) in
            guard success else {
                showAlert(self, "Error deleting psbt", "")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.psbts.remove(at: section)
                self?.lifeHashes.remove(at: section)
                self?.completes.remove(at: section)
                self?.psbtTable.deleteSections(IndexSet.init(arrayLiteral: section), with: .fade)
            }
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
    }
    

}
