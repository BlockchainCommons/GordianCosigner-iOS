//
//  SignersViewController.swift
//  GordianSigner
//
//  Created by Peter on 9/30/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class SignersViewController: UIViewController {

    @IBOutlet weak private var tableView: UITableView!
    
    var addButton = UIBarButtonItem()
    var editButton = UIBarButtonItem()
    var signerStructs = [SignerStruct]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //addButton.tintColor = .de
        //editButton.tintColor = .systemTeal
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
                        
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }
    
    @objc func editSigners() {
        tableView.setEditing(!tableView.isEditing, animated: true)
        
        if tableView.isEditing {
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
                self?.tableView.deleteSections(IndexSet.init(arrayLiteral: section), with: .fade)
            }
            
            showAlert(self, "Signer deleted ✅", "")
        }
    }

}

extension SignersViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
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
        let label = cell.viewWithTag(1) as! UILabel
        let dateAdded = cell.viewWithTag(2) as! UILabel
        let imageView = cell.viewWithTag(3) as! UIImageView
        let fingerprintLabel = cell.viewWithTag(4) as! UILabel
        let isHot = cell.viewWithTag(5) as! UIImageView
        
        cell.selectionStyle = .none
        
        let signer = signerStructs[indexPath.section]
        
        if signer.entropy != nil {
            isHot.alpha = 1
        } else {
            isHot.alpha = 0
        }
        
        label.text = signer.label
        imageView.image = UIImage(data: signer.lifeHash)
        dateAdded.text = signer.dateAdded.formatted()
        fingerprintLabel.text = signer.fingerprint
            
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        
        return cell
    }
    
}