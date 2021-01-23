//
//  AddressesViewController.swift
//  GordianSigner
//
//  Created by Peter on 12/10/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit
import LibWally

class AddressesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var addressesTable: UITableView!
    var addresses = [[String:Any]]()
    var account:AccountStruct!
    let spinner = Spinner()
    var addressToExport = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        addressesTable.delegate = self
        addressesTable.dataSource = self
        load()
        showAlert(self, "⚠️ Verify first!", "To avoid any loss of funds ensure the first few addresses match what your other multisig wallet is showing.")
    }
    
    private func load() {
        spinner.add(vc: self, description: "Loading addresses, this takes a few moments. Please wait.")
        let descriptor = account.descriptor
        let descriptorParser = DescriptorParser()
        let descriptorStruct = descriptorParser.descriptor(descriptor)
        let keys = descriptorStruct.multiSigKeys
        let sigsRequired = descriptorStruct.sigsRequired
        
        DispatchQueue.background(background: { [weak self] in
            guard let self = self else { return }
            
            for i in 0 ... 999 {
                var pubkeys = [PubKey]()
                
                for (k, key) in keys.enumerated() {
                    guard let hdKey = try? HDKey(base58: key.condenseWhitespace()) else {
                        showAlert(self, "Invalid key", "Gordian Cosigner does not yet support slip132, please ensure your xpub is valid and try again.")
                        return
                    }
                    
                    let path = "0" + "/" + "\(i)"
                    
                    guard let bip32path = try? BIP32Path(string: path), let key = try? hdKey.derive(using: bip32path) else {
                        showAlert(self, "", "There was an error deriving your addresses")
                        return
                    }
                    
                    pubkeys.append(key.pubKey)
                    
                    if k + 1 == keys.count {
                        let scriptPubKey = ScriptPubKey(multisig: pubkeys, threshold: sigsRequired, isBIP67: true)
                        
                        if let multiSigAddress = try? Address(scriptPubKey: scriptPubKey, network: Keys.chain) {
                            let lifehash = LifeHash.image(multiSigAddress.description)
                            let dict = ["address": multiSigAddress.description, "lifehash": lifehash] as [String : Any]
                            self.addresses.append(dict)
                        }
                        
                        pubkeys.removeAll()
                    }
                }
                
                if i == 999 {
                    DispatchQueue.main.async { [weak self] in
                        self?.addressesTable.reloadData()
                        self?.spinner.remove()
                    }
                }
            }
        }, completion: {})
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return addresses.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "addressCell", for: indexPath)
        cell.selectionStyle = .default
        
        let dict = addresses[indexPath.row]
        
        let label = cell.viewWithTag(1) as! UILabel
        label.text = "#\(indexPath.row): \(dict["address"] as! String)"
        
        let lifehash = cell.viewWithTag(2) as! UIImageView
        lifehash.layer.magnificationFilter = .nearest
        lifehash.image = (dict["lifehash"] as! UIImage)
        
        let copyButton = cell.viewWithTag(3) as! UIButton
        copyButton.addTarget(self, action: #selector(exportAddress(_:)), for: .touchUpInside)
        copyButton.restorationIdentifier = "\(dict["address"] as! String)"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    @objc func exportAddress(_ sender: UIButton) {
        guard let address = sender.restorationIdentifier else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addressToExport = address
            self.performSegue(withIdentifier: "segueToExportAddress", sender: self)
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToExportAddress" {
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.text = self.addressToExport
                vc.descriptionText = self.addressToExport
                vc.header = "Receive Address"
            }
        }
    }
}
