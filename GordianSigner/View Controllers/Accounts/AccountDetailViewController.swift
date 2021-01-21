//
//  AccountDetailViewController.swift
//  GordianSigner
//
//  Created by Peter on 1/21/21.
//  Copyright © 2021 Blockchain Commons. All rights reserved.
//

import UIKit
import LibWally

class AccountDetailViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    
    var account:AccountStruct!
    var cosigners = [CosignerStruct]()
    var descStruct:Descriptor!
    var cosignerToView:CosignerStruct!
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var thresholdLabel: UILabel!
    @IBOutlet weak var scriptLabel: UILabel!
    @IBOutlet weak var cosignerTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        textField.delegate = self
        cosignerTable.delegate = self
        cosignerTable.dataSource = self
        
        loadCosigners()
        
        let desc = account.descriptor
        let descParser = DescriptorParser()
        descStruct = descParser.descriptor(desc)
        
        thresholdLabel.text = "Threshold: \(descStruct.mOfNType)"
        scriptLabel.text = "Script type: \(descStruct.format)"
        textField.text = account.label
        textField.returnKeyType = .done
    }
    
    @IBAction func seeAddressesAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToAddresses", sender: self)
        }
    }
    
    
    @IBAction func exportAccountAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToExportAccountMap", sender: self)
        }
    }
    
    
    private func showCosignerDetail() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToCosignerFromAccountDetail", sender: self)
        }
    }
    
    private func loadCosigners() {
        CoreDataService.retrieveEntity(entityName: .cosigner) { [weak self] (savedCosigners, errorDescription) in
            guard let self = self else { return }
            
            guard let savedCosigners = savedCosigners, savedCosigners.count > 0 else { return }
            for (i, cosigner) in savedCosigners.enumerated() {
                let cosignerStruct = CosignerStruct(dictionary: cosigner)
                if let desc = cosignerStruct.bip48SegwitAccount {
                    if self.account.descriptor.contains(desc) {
                        self.cosigners.append(cosignerStruct)
                    }
                }
                
                if i + 1 == savedCosigners.count {
                    for (k, keyPath) in self.descStruct.keysWithPath.enumerated() {
                        
                        var isKnown = false
                        
                        for (c, cs) in self.cosigners.enumerated() {
                            if cs.bip48SegwitAccount!.contains(keyPath) {
                                isKnown = true
                            }
                            
                            if c + 1 == self.cosigners.count {
                                if !isKnown {
                                    var dict = [String:Any]()
                                    let hack = "wsh(\(keyPath)/0/*)"
                                    let dp = DescriptorParser()
                                    let ds = dp.descriptor(hack)
                                    dict["label"] = "Unknown Cosigner"
                                    dict["lifehash"] = LifeHash.hash(self.descStruct.multiSigKeys[k])
                                    dict["bip48SegwitAccount"] = keyPath
                                    dict["id"] = UUID()
                                    dict["dateAdded"] = Date()
                                    dict["fingerprint"] = ds.fingerprint
                                    
                                    let cs = CosignerStruct(dictionary: dict)
                                    self.cosigners.append(cs)
                                }
                                
                                if k + 1 == self.descStruct.keysWithPath.count {
                                    DispatchQueue.main.async { [weak self] in
                                        guard let self = self else { return }
                                        self.cosignerTable.reloadData()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if cosigners.count == 0 {
            return 0
        } else {
            return descStruct.multiSigKeys.count
        }
    }
    
    private func cosignerCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = cosignerTable.dequeueReusableCell(withIdentifier: "accountCosignerCell", for: indexPath)
        cell.selectionStyle = .none
        
        let cosigner = cosigners[indexPath.row]
        
        let lifehashView = cell.viewWithTag(1) as! LifehashSeedView
        let isHotImage = cell.viewWithTag(2) as! UIImageView
        
        lifehashView.backgroundColor = cell.backgroundColor
        lifehashView.background.backgroundColor = cell.backgroundColor
        lifehashView.iconImage.image = UIImage(systemName: "person.2")
        
        if cosigner.xprv != nil || cosigner.words != nil {
            isHotImage.image = UIImage(systemName: "flame")
            isHotImage.tintColor = .systemOrange
        } else {
            isHotImage.image = UIImage(systemName: "snow")
            isHotImage.tintColor = .white
        }
        
        lifehashView.lifehashImage.image = UIImage(data: cosigner.lifehash) ?? UIImage()
        lifehashView.iconLabel.text = cosigner.label
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        cosignerCell(indexPath)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let newLabel = textField.text else { return }
        
        CoreDataService.updateEntity(id: account.id, keyToUpdate: "label", newValue: newLabel, entityName: .account) { (success, errorDescription) in
            guard success else { showAlert(self, "", "Label not updated!"); return }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.cosignerToView = cosigners[indexPath.row]
        showCosignerDetail()
    }

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        switch segue.identifier {
        case "segueToCosignerFromAccountDetail":
            guard let vc = segue.destination as? SeedDetailViewController else { fallthrough }
            
            vc.cosigner = self.cosignerToView
            
        case "segueToExportAccountMap":
            guard let vc = segue.destination as? QRDisplayerViewController else { fallthrough }
            
            guard let map = try? JSONSerialization.jsonObject(with: account.map, options: []) as? [String:Any] else { return }
            
            vc.header = account.label
            vc.descriptionText = map.json() ?? ""
            vc.isPsbt = false
            vc.text = map.json() ?? ""
            
        case "segueToAddresses":
            guard let vc = segue.destination as? AddressesViewController else { fallthrough }
            
            vc.account = self.account
            
        default:
            break
        }
    }
}
