//
//  SignersViewController.swift
//  GordianSigner
//
//  Created by Peter on 9/30/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class SignersViewController: UIViewController {

    @IBOutlet weak var signerTable: UITableView!
    
    var addButton = UIBarButtonItem()
    var editButton = UIBarButtonItem()
    var signerStructs = [SignerStruct]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        signerTable.delegate = self
        addButton = UIBarButtonItem.init(barButtonSystemItem: .add, target: self, action: #selector(add))
        editButton = UIBarButtonItem.init(barButtonSystemItem: .edit, target: self, action: #selector(editSigners))
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadData()
    }
    
    @objc func add() {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToAddASigner", sender: self)
        }
    }
    
    private func loadData() {
        signerStructs.removeAll()
        
        CoreDataService.retrieveEntity(entityName: .signer) { [weak self] (signers, errorDescription) in
            guard let self = self, let signers = signers, signers.count > 0 else { return }
            
            for (i, signer) in signers.enumerated() {
                let signerStruct = SignerStruct(dictionary: signer)
                self.signerStructs.append(signerStruct)
                
                if i + 1 == signers.count {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.signerTable.reloadData()
                    }
                }
            }
        }
    }
    
    @objc func editSigners() {
        signerTable.setEditing(!signerTable.isEditing, animated: true)
        
        if signerTable.isEditing {
            editButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(editSigners))
        } else {
            editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editSigners))
        }
        
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
    }
    
    @objc func deleteSeed(_ id: UUID, _ section: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            
            let alert = UIAlertController(title: "Delete signer?", message: "This action is undoable! The signer will be gone forever.", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
                self.deleteSeedNow(id, section)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func deleteSeedNow(_ id: UUID, _ section: Int) {
        CoreDataService.deleteEntity(id: id, entityName: .signer) { (success, errorDescription) in
            guard success else {
                showAlert(self, "Error deleting signer", "We were unable to delete that signer!")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.signerStructs.remove(at: section)
                self?.signerTable.deleteSections(IndexSet.init(arrayLiteral: section), with: .fade)
            }
            
            showAlert(self, "", "Signer deleted ✓")
        }
    }
    
    @objc func editLabel(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let int = Int(sectionString) else { return }
        
        let signer = signerStructs[int]
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Edit Signer label"
            let message = ""
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let save = UIAlertAction(title: "Save", style: .default) { [weak self] (alertAction) in
                guard let self = self else { return }
                
                let textField1 = (alert.textFields![0] as UITextField).text
                
                guard let updatedLabel = textField1, updatedLabel != "" else { return }
                
                self.updateLabel(signer.id, updatedLabel, signer.cosigner ?? "?")
            }
            
            alert.addTextField { (textField) in
                textField.text = signer.label
                textField.isSecureTextEntry = false
                textField.keyboardAppearance = .dark
            }
            
            alert.addAction(save)
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                self.loadData()
            }))
            
            self.present(alert, animated:true, completion: nil)
        }
    }
    
    private func updateLabel(_ id: UUID, _ label: String, _ cosigner: String) {
        CoreDataService.updateEntity(id: id, keyToUpdate: "label", newValue: label, entityName: .signer) { (success, errorDescription) in
            guard success else { showAlert(self, "Label not saved!", "There was an error updating your label, please let us know about it: \(errorDescription ?? "unknown")"); return }
            
            self.updateCosignerLabelToo(cosigner, label)
            //self.loadData()
        }
    }
    
    private func updateCosignerLabelToo(_ keyset: String, _ label: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Update cosigner?", message: "The seed label has been updated, would you also like to update the corresponding cosigner label?", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Update", style: .default, handler: { action in
                CoreDataService.retrieveEntity(entityName: .keyset) { (cosigners, errorDescription) in
                    guard let cosigners = cosigners, cosigners.count > 0 else { self.loadData(); return }
                    
                    var id:UUID?
                    for cosigner in cosigners {
                        let csStruct = KeysetStruct(dictionary: cosigner)
                        if csStruct.bip48SegwitAccount == keyset {
                            id = csStruct.id
                        }
                    }
                    if id != nil {
                        CoreDataService.updateEntity(id: id!, keyToUpdate: "label", newValue: label, entityName: .keyset) { (success, errorDescription) in
                            guard success else {
                                self.loadData()
                                showAlert(self, "", "Cosigner label not updated! There was a problem saving the new label.")
                                return
                            }
                            
                            self.loadData()
                            showAlert(self, "", "Cosigner label updated ✓")
                        }
                    } else {
                        self.loadData()
                        showAlert(self, "", "No corresponding cosigner exists")
                    }
                    
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                self.loadData()
            }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }

}

extension SignersViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 105
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let signer = signerStructs[indexPath.section]
            deleteSeed(signer.id, indexPath.section)
        }
    }
    
}

extension SignersViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return signerStructs.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "signerCell", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.cornerRadius = 8
        cell.layer.borderColor = UIColor.darkGray.cgColor
        cell.layer.borderWidth = 0.5
        
        let label = cell.viewWithTag(1) as! UILabel
        let dateAdded = cell.viewWithTag(2) as! UILabel
        let imageView = cell.viewWithTag(3) as! UIImageView
        let fingerprintLabel = cell.viewWithTag(4) as! UILabel
        
        let editButton = cell.viewWithTag(6) as! UIButton
        editButton.addTarget(self, action: #selector(editLabel(_:)), for: .touchUpInside)
        editButton.restorationIdentifier = "\(indexPath.section)"
        editButton.showsTouchWhenHighlighted = true
        
        let signer = signerStructs[indexPath.section]
        
        label.text = signer.label
        imageView.image = UIImage(data: signer.lifeHash)
        dateAdded.text = signer.dateAdded.formatted()
        fingerprintLabel.text = signer.fingerprint
            
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        
        return cell
    }
    
}
