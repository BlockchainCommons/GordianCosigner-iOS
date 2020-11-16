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
    var accountMaps = [AccountMapStruct]()
    
    @IBOutlet weak var accountMapTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        addButton.tintColor = .systemTeal
        editButton.tintColor = .systemTeal
        addButton = UIBarButtonItem.init(barButtonSystemItem: .add, target: self, action: #selector(add))
        editButton = UIBarButtonItem.init(barButtonSystemItem: .edit, target: self, action: #selector(editSigners))
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
    }
    
    private func load() {
        accountMaps.removeAll()
        
        CoreDataService.retrieveEntity(entityName: .accountMap) { [weak self] (accountMaps, errorDescription) in
            guard let self = self else { return }
            
            guard let accountMaps = accountMaps, accountMaps.count > 0 else { return }
            
            for accountMap in accountMaps {
                let str = AccountMapStruct(dictionary: accountMap)
                
                self.accountMaps.append(str)
            }
            
            DispatchQueue.main.async {
                self.accountMapTable.reloadData()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return accountMaps.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "accountMapCell", for: indexPath)
        cell.selectionStyle = .none
        
        let accountMap = accountMaps[indexPath.section]
        
        let label = cell.viewWithTag(1) as! UILabel
        label.text = accountMap.label
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 267
    }
    
    @objc func add() {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToAddAccountMap", sender: self)
        }
    }
    
    @objc func editSigners() {
        accountMapTable.setEditing(!accountMapTable.isEditing, animated: true)
        
        if accountMapTable.isEditing {
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
            
            let alert = UIAlertController(title: "Delete Account Map?", message: "", preferredStyle: alertStyle)
            
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
                showAlert(self, "Error deleting Account Map", "We were unable to delete that signer!")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.accountMaps.remove(at: section)
                self?.accountMapTable.deleteSections(IndexSet.init(arrayLiteral: section), with: .fade)
            }
            
            showAlert(self, "Account Map deleted ✅", "")
        }
    }
    
    private func parseAccountMap(_ accountMap: String) {
        guard let dict = try? JSONSerialization.jsonObject(with: accountMap.utf8, options: []) as? [String:Any] else { return }
        
        guard var descriptor = dict["descriptor"] as? String else { return }
        
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
                let dict = ["path":"\(arr[0])]", "key": "\(arr[1].replacingOccurrences(of: "))", with: ""))"]
                dictArray.append(dict)
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
            
            let arr2 = descriptor.split(separator: ",")
            descriptor = "\(arr2[0])," + sortedKeys + "))"
        }
        
        var map = [String:Any]()
        map["birthblock"] = Int64(dict["birthblock"] as? Int ?? 0)
        map["accountMap"] = accountMap.utf8
        map["label"] = dict["label"] as? String ?? "Account map"
        map["id"] = UUID()
        map["dateAdded"] = Date()
        map["complete"] = descStruct.complete
        map["lifehash"] = LifeHash.hash(descriptor.utf8)
        map["descriptor"] = descriptor
        
        CoreDataService.saveEntity(dict: map, entityName: .accountMap) { [weak self] (success, errorDescription) in
            guard let self = self, success else { return }
            
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
    }

}
