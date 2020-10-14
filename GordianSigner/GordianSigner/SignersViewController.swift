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
    
    var fingeprints = [String]()
    var addButton = UIBarButtonItem()
    var editButton = UIBarButtonItem()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addButton.tintColor = .systemTeal
        editButton.tintColor = .systemTeal
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
        fingeprints.removeAll()
        guard let signers = Encryption.decryptedSeeds(), signers.count > 0 else { return }
        for signer in signers {
            guard let masterKey = Keys.masterKey(signer, ""),
                let fingerprint = Keys.fingerprint(masterKey) else {
                    return
            }
            fingeprints.append(fingerprint)
        }
        tableView.reloadData()
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
    
    @objc func deleteSeed(_ xfp: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            
            let alert = UIAlertController(title: "Delete signer?", message: "This action is undoable! The signer will be gone forever.", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
                self.deleteSeedNow(xfp)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func deleteSeedNow(_ xfp: String) {
        let spinner = Spinner()
        spinner.add(vc: self, description: "deleting signer...")
        
        guard var signers = Encryption.decryptedSeeds(), signers.count > 0 else { return }
        
        for (i, signer) in signers.enumerated() {
            guard let masterKey = Keys.masterKey(signer, ""),
                let fingerprint = Keys.fingerprint(masterKey) else {
                    return
            }
            if fingerprint == xfp {
                signers.remove(at: i)
            }
        }
        
        if signers.count > 0 {
            KeyChain.overWriteExistingSeeds(signers) { success in
                if success {
                    self.loadData()
                    spinner.remove()
                    showAlert(self, "Success ✓", "Signer has been removed")
                } else {
                    spinner.remove()
                    showAlert(self, "Error", "There was an error removing your signer")
                }
            }
        } else {
            if KeyChain.remove(key: "seeds") {
                self.loadData()
                spinner.remove()
                showAlert(self, "Success ✓", "Signer has been removed")
            } else {
                spinner.remove()
                showAlert(self, "Error", "There was an error removing your signer")
            }
        }
    }

}

extension SignersViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let fingerprint = fingeprints[indexPath.section]
            deleteSeed(fingerprint)
        }
    }
    
}

extension SignersViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return fingeprints.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "signerCell", for: indexPath)
        let label = cell.viewWithTag(1) as! UILabel
        let imageView = cell.viewWithTag(3) as! UIImageView
        let backgroundView = cell.viewWithTag(4)!
        
        cell.selectionStyle = .none
        
        label.text = fingeprints[indexPath.section]
    
        imageView.tintColor = .white
        
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerRadius = 5
        backgroundView.backgroundColor = .systemBlue
        return cell
    }
    
}
