//
//  PsbtTableViewController.swift
//  GordianSigner
//
//  Created by Peter on 11/12/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit
import LibWally
import AuthenticationServices

class PsbtTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    @IBOutlet weak private var tableView: UITableView!
    @IBOutlet weak private var signButtonOutlet: UIButton!
    
    private var spinner = Spinner()
    var rawTx = ""
    var psbtStruct:PsbtStruct!
    var psbt:PSBT!
    var signedPsbt:PSBT!
    private var canSign = false
    private var alertStyle = UIAlertController.Style.actionSheet
    var inputsArray = [[String:Any]]()
    var outputsArray = [[String:Any]]()
    var signedFor = [String]()
    var accounts = [AccountStruct]()
    var isComplete = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.delegate = self
        tableView.dataSource = self
        
        signButtonOutlet.layer.cornerRadius = 8
        signButtonOutlet.alpha = 0
        
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
        }
                
        psbt = try? PSBT(psbt: psbtStruct.psbt, network: Keys.chain)
        
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .cosignerAdded, object: nil)
        
        loadTable()
    }
    
    @objc func refresh() {
        loadTable()
    }
    
    private func loadTable() {
        spinner.add(vc: self, description: "loading...")
        
        load { success in
            if success {
                DispatchQueue.main.async { [weak self] in
                    self?.tableView.reloadData()
                    
                }
            }
            self.spinner.remove()
        }
    }
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    
    private func load(completion: @escaping ((Bool) -> Void)) {
        inputsArray.removeAll()
        outputsArray.removeAll()
        accounts.removeAll()
        
        CoreDataService.retrieveEntity(entityName: .account) { (accounts, errorDescription) in
            if accounts != nil {
                if accounts!.count > 0 {
                    for account in accounts! {
                        let str = AccountStruct(dictionary: account)
                        if !str.descriptor.contains("keyset") {
                            self.accounts.append(AccountStruct(dictionary: account))
                        }
                    }
                }
            }
        }
        
        if let final = try? psbt.finalized() {
            if let _ = final.transactionFinal {
                self.isComplete = true
            }
        }
        
        let inputs = self.psbt.inputs
        
        for (i, input) in inputs.enumerated() {
            var pubkeysArray = [[String:Any]]()
            self.inputsArray.append(["input": input])
            
            if let origins = input.origins {
                for (o, origin) in origins.enumerated() {
                    let pubkey = origin.key.data.hexString
                    
                    var dict:[String:Any]!
                    
                    self.inputsArray[i]["fullPath"] = origin.value.path.description
                    
                    if let path = try? origin.value.path.chop(depth: 4) {
                        dict = ["pubkey":pubkey, "hasSigned": false, "cosignerLabel": "unknown", "path": path, "fullPath": origin.value.path] as [String : Any]
                    } else {
                        dict = ["pubkey":pubkey, "hasSigned": false, "cosignerLabel": "unknown", "fullPath": origin.value.path] as [String : Any]
                    }
                    
                    pubkeysArray.append(dict)
                    
                    if o + 1 == origins.count {
                        self.inputsArray[i]["pubKeyArray"] = pubkeysArray
                        
                        // Need ability to determine threshhold from input in order to produce an address.
                        
//                        var pubKeys = [Key]()
//                        for pk in pubkeysArray {
//                            let pubkey = pk["pubkey"] as! String
//                            if let k = try? Key(Data(value: pubkey), network: .mainnet) {
//                                pubKeys.append(k)
//                            }
//                        }
//
//                        let script = ScriptPubKey(multisig: <#T##[PubKey]#>, threshold: <#T##UInt#>, isBIP67: <#T##Bool#>)
                        
                    }
                    
                    if i + 1 == inputs.count && o + 1 == origins.count {
                        self.parsePubkeys(completion: completion)
                    }
                }
            } else {
                if i + 1 == inputs.count {
                    self.parsePubkeys(completion: completion)
                }
            }
        }
    }
    
    private func parsePubkeys(completion: @escaping ((Bool) -> Void)) {
        CoreDataService.retrieveEntity(entityName: .cosigner) { [weak self] (cosigners, errorDescription) in
            guard let self = self else { completion(false); return }
            
            guard let cosigners = cosigners, cosigners.count > 0 else { completion(false); return }
            
            DispatchQueue.background(background: {
                for (i, inputDictArray) in self.inputsArray.enumerated() {
                    let input = inputDictArray["input"] as! PSBTInput
                    if var pubkeyArray = inputDictArray["pubKeyArray"] as? [[String:Any]] {
                        for (p, pubkeyDict) in pubkeyArray.enumerated() {
                            var updatedDict = pubkeyDict
                            
                            let originalPubkey = pubkeyDict["pubkey"] as! String
                            let fullPath = pubkeyDict["fullPath"] as! BIP32Path
                            updatedDict["hasSigned"] = false
                            updatedDict["canSign"] = false
                            
                            func loopCosigners() {
                                for (k, keyset) in cosigners.enumerated() {
                                    let cosignerStruct = CosignerStruct(dictionary: keyset)
                                    
                                    if let descriptor = cosignerStruct.bip48SegwitAccount {
                                        let arr = descriptor.split(separator: "]")
                                        var xpub = ""
                                        
                                        if arr.count > 0 {
                                            xpub = "\(arr[1])".replacingOccurrences(of: "))", with: "")
                                        }
                                        
                                        if let path = pubkeyDict["path"] as? BIP32Path,
                                            let hdkey = try? HDKey(base58: xpub),
                                            let childKey = try? hdkey.derive(using: path) {
                                            if originalPubkey == childKey.pubKey.data.hexString {
                                                updatedDict["cosignerLabel"] = cosignerStruct.label
                                                updatedDict["lifeHash"] = LifeHash.image(cosignerStruct.lifehash) ?? UIImage()
                                                
                                                if let desc = cosignerStruct.bip48SegwitAccount {
                                                    let dp = DescriptorParser()
                                                    let ds = dp.descriptor("wsh(\(desc))")
                                                    let xfp = ds.fingerprint
                                                    updatedDict["cosignerOrigin"] = "[" + fullPath.description.replacingOccurrences(of: "m", with: xfp) + "]"
                                                }
                                                
                                                pubkeyArray[p] = updatedDict
                                                
                                                if let sigs = input.signatures {
                                                    
                                                    for (s, sig) in sigs.enumerated() {
                                                        let signedKey = sig.key.data.hexString
                                                        
                                                        if signedKey == originalPubkey {
                                                            updatedDict["hasSigned"] = true
                                                            pubkeyArray[p] = updatedDict
                                                            self.inputsArray[i]["pubKeyArray"] = pubkeyArray
                                                        }
                                                        
                                                        if self.signedFor.count > 0 {
                                                            
                                                            for (x, signed) in self.signedFor.enumerated() {
                                                                
                                                                if signed == originalPubkey {
                                                                    updatedDict["hasSigned"] = true
                                                                    pubkeyArray[p] = updatedDict
                                                                    self.inputsArray[i]["pubKeyArray"] = pubkeyArray
                                                                }
                                                                
                                                                if k + 1 == cosigners.count && p + 1 == pubkeyArray.count && i + 1 == self.inputsArray.count && s + 1 == sigs.count && x + 1 == self.signedFor.count {
                                                                    self.parseOutputs(completion: completion)
                                                                }
                                                            }
                                                            
                                                        } else {
                                                            self.inputsArray[i]["pubKeyArray"] = pubkeyArray
                                                            
                                                            if k + 1 == cosigners.count && p + 1 == pubkeyArray.count && i + 1 == self.inputsArray.count && s + 1 == sigs.count {
                                                                self.parseOutputs(completion: completion)
                                                            }
                                                        }
                                                    }
                                                    
                                                } else {
                                                    self.inputsArray[i]["pubKeyArray"] = pubkeyArray
                                                    
                                                    if k + 1 == cosigners.count && p + 1 == pubkeyArray.count && i + 1 == self.inputsArray.count {
                                                        self.parseOutputs(completion: completion)
                                                    }
                                                }
                                                
                                            } else {
                                                // It is an unknown cosigner
                                                if let sigs = input.signatures {
                                                    for sig in sigs {
                                                        let signedKey = sig.key.data.hexString
                                                        if signedKey == originalPubkey {
                                                            updatedDict["hasSigned"] = true
                                                            pubkeyArray[p] = updatedDict
                                                            self.inputsArray[i]["pubKeyArray"] = pubkeyArray
                                                        }
                                                    }
                                                } else {
                                                    self.inputsArray[i]["pubKeyArray"] = pubkeyArray
                                                }
                                                
                                                if k + 1 == cosigners.count && p + 1 == pubkeyArray.count && i + 1 == self.inputsArray.count {
                                                    self.parseOutputs(completion: completion)
                                                }
                                            }
                                            
                                        } else {
                                            self.inputsArray[i]["pubKeyArray"] = pubkeyArray
                                            
                                            if k + 1 == cosigners.count && p + 1 == pubkeyArray.count && i + 1 == self.inputsArray.count {
                                                self.parseOutputs(completion: completion)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            CoreDataService.retrieveEntity(entityName: .cosigner) { (cosigners, errorDescription) in
                                if let cosigners = cosigners, cosigners.count > 0 {

                                    for (s, cosigner) in cosigners.enumerated() {
                                        let cosignerStruct = CosignerStruct(dictionary: cosigner)
                                        
                                        if let encryptedXprv = cosignerStruct.xprv {
                                            if let decryptedXprv = Encryption.decrypt(encryptedXprv) {
                                                if let hdkey = try? HDKey(base58: decryptedXprv.utf8) {
                                                    if let accountPath = try? fullPath.chop(depth: 4) {
                                                        if let childKey = try? hdkey.derive(using: accountPath) {
                                                            if childKey.pubKey.data.hexString == originalPubkey {
                                                                self.canSign = true
                                                                updatedDict["canSign"] = true
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        if let encryptedXprv = cosignerStruct.masterKey {
                                            if let decryptedXprv = Encryption.decrypt(encryptedXprv) {
                                                if let hdkey = try? HDKey(base58: decryptedXprv.utf8) {
                                                    if let childKey = try? hdkey.derive(using: fullPath) {
                                                        if childKey.pubKey.data.hexString == originalPubkey {
                                                            self.canSign = true
                                                            updatedDict["canSign"] = true
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        if s + 1 == cosigners.count {
                                            loopCosigners()
                                        }
                                    }
                                } else {
                                    loopCosigners()
                                }
                            }

                        }
                    } else {
                        self.parseOutputs(completion: completion)
                    }
                }
            }, completion: {})
        }
    }
    
    private func updateButton() {
        for input in inputsArray {
            if let pubkeyArray = input["pubKeyArray"] as? [[String:Any]] {
                for pubkey in pubkeyArray {
                    let canSign = pubkey["canSign"] as? Bool ?? false
                    let hasSigned = pubkey["hasSigned"] as? Bool ?? false
                    
                    if canSign {
                        if !hasSigned {
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                
                                self.signButtonOutlet.alpha = 1
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func parseOutputs(completion: @escaping ((Bool) -> Void)) {
        updateButton()
        
        let outputs = psbt.outputs
        
        for (o, output) in outputs.enumerated() {
            self.outputsArray.append(["output": output])
            
            if let address = output.txOutput.address {
                self.outputsArray[o]["address"] = address
                self.outputsArray[o]["isMine"] = false
                self.outputsArray[o]["accountMap"] = "unknown"
                self.outputsArray[o]["path"] = "path unknown"
                
                if accounts.count == 0 && o + 1 == outputs.count {
                    completion(true)
                }
                
                for (a, accountMap) in accounts.enumerated() {
                    let descriptor = accountMap.descriptor
                    if !descriptor.contains("keyset") {
                        let descriptorParser = DescriptorParser()
                        let descriptorStruct = descriptorParser.descriptor(descriptor)
                        let keys = descriptorStruct.multiSigKeys
                        let sigsRequired = descriptorStruct.sigsRequired
                        
                        if let origins = output.origins {
                            for (x, origin) in origins.enumerated() {
                                let path = origin.value.path
                                self.outputsArray[o]["path"] = path.description
                                var pubkeys = [PubKey]()
                                
                                for (k, key) in keys.enumerated() {
                                    if let hdkey = try? HDKey(base58: key), let pubkey = try? hdkey.derive(using: path.chop(depth: 4)) {
                                        pubkeys.append(pubkey.pubKey)
                                        
                                        if k + 1 == keys.count {
                                            let scriptPubKey = ScriptPubKey(multisig: pubkeys, threshold: sigsRequired, isBIP67: true)
                                            guard let multiSigAddress = try? Address(scriptPubKey: scriptPubKey, network: Keys.chain) else { return }
                                                                            
                                            if multiSigAddress.description == address {
                                                self.outputsArray[o]["isMine"] = true
                                                self.outputsArray[o]["map"] = accountMap.label
                                                self.outputsArray[o]["lifeHash"] = LifeHash.image(descriptor)
                                            }
                                            
                                            if a + 1 == accounts.count && o + 1 == outputs.count && x + 1 == origins.count {
                                                completion(true)
                                            }
                                        }
                                    } else {
                                        if k + 1 == keys.count && a + 1 == accounts.count && o + 1 == outputs.count && x + 1 == origins.count {
                                            completion(true)
                                        }
                                    }
                                }
                            }
                        } else {
                            if a + 1 == accounts.count && o + 1 == outputs.count {
                                completion(true)
                            }
                        }
                    }
                }
            } else {
                if o + 1 == outputs.count {
                    completion(true)
                }
            }
        }
    }
    
    @IBAction func signAction(_ sender: Any) {
        #if DEBUG
        sign()
        #else
        showAuth()
        #endif
    }
    
    @IBAction func exportAction(_ sender: Any) {
        exportAction()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView.tag == 3 {
            return (inputsArray[section]["pubKeyArray"] as? [[String:Any]] ?? [[:]]).count
        } else {
            switch section {
            case 3:
                return psbt.inputs.count
            case 4:
                return psbt.outputs.count
            default:
                return 1
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if tableView.tag == 3 {
            return 1
        } else {
            return 6
        }
    }
    
    private func cosignersCell(_ table: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
        let cell = table.dequeueReusableCell(withIdentifier: "participantsCell", for: indexPath)
        cell.selectionStyle = .none
        
        let lifeHashView = cell.viewWithTag(2) as! LifehashSeedView
        let sigImage = cell.viewWithTag(3) as! UIImageView
        let isHotImage = cell.viewWithTag(4) as! UIImageView
        
        lifeHashView.backgroundColor = cell.backgroundColor
        lifeHashView.background.backgroundColor = cell.backgroundColor
        lifeHashView.iconImage.image = UIImage(systemName: "person.2")
        
        sigImage.tintColor = .systemPink
        
        if let participants = inputsArray[indexPath.section]["pubKeyArray"] as? [[String:Any]] {
            let participant = participants[indexPath.row]
            let cosignerLabel = participant["cosignerLabel"] as? String ?? "unknown"
            let hasSigned = participant["hasSigned"] as? Bool ?? false
            let canSign = participant["canSign"] as? Bool ?? false
            
            if canSign {
                isHotImage.image = UIImage(systemName: "flame")
                isHotImage.tintColor = .systemOrange
            } else {
                isHotImage.image = UIImage(systemName: "snow")
                isHotImage.tintColor = .white
            }
            
            if hasSigned {
                sigImage.image = UIImage(systemName: "signature")
                sigImage.tintColor = .systemGreen
            } else {
                sigImage.image = UIImage(systemName: "exclamationmark.square")
            }
            
            if cosignerLabel != "unknown" {
                if let lifehash = participant["lifeHash"] as? UIImage {
                    lifeHashView.lifehashImage.image = lifehash
                }
                lifeHashView.iconLabel.text = cosignerLabel
            } else {
                lifeHashView.iconLabel.text = "UNKNOWN COSIGNER!"
                lifeHashView.lifehashImage.image = UIImage(systemName: "person.crop.circle.badge.exclam")
                lifeHashView.lifehashImage.tintColor = .systemRed
            }
        } else {
            isHotImage.alpha = 0
            sigImage.alpha = 0
            lifeHashView.iconLabel.text = "UNKNOWN COSIGNER!"
            lifeHashView.lifehashImage.image = UIImage(systemName: "person.crop.circle.badge.exclam")
            lifeHashView.lifehashImage.tintColor = .systemRed
        }
        
        return cell
    }
 
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView.tag == 3 {
            tableView.layer.cornerRadius = 8
            return cosignersCell(tableView, indexPath)
        } else {
            switch indexPath.section {
            case 0:
                return labelCell(indexPath)
            case 1:
                return memoCell(indexPath)
            case 2:
                return completeCell(indexPath)
            case 3:
                if inputsArray.count > 0 {
                    return inputCell(indexPath)
                } else {
                    return UITableViewCell()
                }
            case 4:
                if outputsArray.count > 0 {
                    return outputCell(indexPath)
                } else {
                    return UITableViewCell()
                }
            case 5:
                return feeCell(indexPath)
            default:
                return UITableViewCell()
            }
        }
    }
    
    private func configureCell(_ cell: UITableViewCell) {
        cell.clipsToBounds = true
        cell.layer.cornerRadius = 8
        cell.selectionStyle = .none
        cell.layer.borderWidth = 0.5
        cell.layer.borderColor = UIColor.lightGray.cgColor
    }
    
    private func configureView(_ view: UIView) {
        view.clipsToBounds = true
        view.layer.cornerRadius = 8
    }
    
    private func completeCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "completeCell", for: indexPath)
        configureCell(cell)
        
        let label = cell.viewWithTag(1) as! UILabel
        let icon = cell.viewWithTag(2) as! UIImageView
        let addCosignerButton = cell.viewWithTag(3) as! UIButton
        
        addCosignerButton.addTarget(self, action: #selector(addCosigner(_:)), for: .touchUpInside)
        
        if isComplete {
            label.text = "Signatures complete"
            icon.image = UIImage(systemName: "checkmark.square")
            icon.tintColor = .systemGreen
            addCosignerButton.alpha = 0
        } else {
            label.text = "Signatures required"
            icon.image = UIImage(systemName: "exclamationmark.square")
            icon.tintColor = .systemPink
            if !canSign {
                addCosignerButton.alpha = 1
            } else {
                addCosignerButton.alpha = 0
            }
            
        }
        
        return cell
    }
    
    private func inputCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "inputCell", for: indexPath)
        configureCell(cell)
                
        let amountLabel = cell.viewWithTag(2) as! UILabel
        let participantsTableView = cell.viewWithTag(3) as! UITableView
        participantsTableView.delegate = self
        participantsTableView.frame = CGRect(x: 0, y: 0, width: tableView.frame.width, height: 300)
        let numberOfSigsLabel = cell.viewWithTag(6) as! UILabel
        
        let pathLabel = cell.viewWithTag(8) as! UILabel
        pathLabel.text = "path unknown"
        
        let inputNumberLabel = cell.viewWithTag(7) as! UILabel
        inputNumberLabel.text = "Input #\(indexPath.row + 1)"
        
        let inputTypeImageView = cell.viewWithTag(9) as! UIImageView
        let inputTypeLabel = cell.viewWithTag(5) as! UILabel
                
        let inputDict = inputsArray[indexPath.row]
        let input = inputDict["input"] as! PSBTInput
        
        if let fullPath = inputDict["fullPath"] as? String {
            pathLabel.text = fullPath
            
            if fullPath.contains("/0/") {
                inputTypeImageView.image = UIImage(systemName: "arrow.down.right")
                inputTypeLabel.text = "Receive Input"
                inputTypeImageView.tintColor = .systemGreen
            } else if fullPath.contains("/1/") {
                inputTypeImageView.image = UIImage(systemName: "arrow.2.circlepath")
                inputTypeLabel.text = "Change Input"
                inputTypeImageView.tintColor = .gray
            } else {
                inputTypeImageView.image = UIImage(systemName: "questionmark.circle")
                inputTypeLabel.text = "Unknown type"
                inputTypeImageView.tintColor = .systemRed
            }
        } else {
            pathLabel.text = "unknown"
            inputTypeImageView.image = UIImage(systemName: "questionmark.circle")
            inputTypeLabel.text = "Unknown type"
            inputTypeImageView.tintColor = .systemRed
        }
        
        if let pubkeyArray = inputDict["pubKeyArray"] as? [[String:Any]], pubkeyArray.count > 0 {
            numberOfSigsLabel.text = "?"
            var numberOfSigs = 0
            for pubkey in pubkeyArray {
                let hasSigned = pubkey["hasSigned"] as! Bool
                if hasSigned {
                    numberOfSigs += 1
                }
            }
            numberOfSigsLabel.text = "\(numberOfSigs) signatures"
        } else {
            numberOfSigsLabel.text = "?"
        }
        
        if let amount = input.amount {
            amountLabel.text = "\(Double(amount) / 100000000.0) btc"
        }
        
        DispatchQueue.main.async {
            participantsTableView.reloadData()
        }
        
        return cell
    }
    
    private func outputCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "outputCell", for: indexPath)
        configureCell(cell)
        
        let outputLabel = cell.viewWithTag(1) as! UILabel
        
        let lifehashView = cell.viewWithTag(2) as! LifehashSeedView
        lifehashView.backgroundColor = cell.backgroundColor
        lifehashView.background.backgroundColor = cell.backgroundColor
        
        let amountLabel = cell.viewWithTag(3) as! UILabel
        let addressLabel = cell.viewWithTag(4) as! UILabel
        let pathLabel = cell.viewWithTag(6) as! UILabel
        let addressTypeImage = cell.viewWithTag(7) as! UIImageView
        let addressTypeLabel = cell.viewWithTag(8) as! UILabel
        let outputDict = outputsArray[indexPath.row]
        let output = outputDict["output"] as! PSBTOutput
        
        outputLabel.text = "Output #\(indexPath.row + 1)"
        
        let isMine = outputDict["isMine"] as! Bool
        lifehashView.iconImage.image = UIImage(systemName: "person.2.square.stack")
                
        if isMine {
            if let lifehash = outputDict["lifeHash"] as? UIImage {
                lifehashView.lifehashImage.image = lifehash
            }
            lifehashView.iconLabel.text = outputDict["map"] as? String ?? ""
        } else {
            lifehashView.lifehashImage.image = UIImage(systemName: "person.crop.circle.badge.exclam")
            lifehashView.lifehashImage.tintColor = .systemRed
            lifehashView.iconLabel.text = "UNKNOWN RECIPIENT!"
        }
        
        amountLabel.text = (Double(output.txOutput.amount) / 100000000.0).avoidNotation + " btc"
        
        if let address = output.txOutput.address {
            addressLabel.text = address
        } else {
            addressLabel.text = "no address..."
        }
        addressLabel.adjustsFontSizeToFitWidth = true
        
        let path = outputDict["path"] as! String
        pathLabel.text = path
        
        if path.contains("/1/") {
            addressTypeImage.image = UIImage(systemName: "arrow.2.circlepath")
            addressTypeLabel.text = "Change address:"
            addressTypeImage.tintColor = .darkGray
        } else if path.contains("/0/") {
            addressTypeImage.image = UIImage(systemName: "arrow.down.right")
            addressTypeLabel.text = "Receive address:"
            addressTypeImage.tintColor = .systemGreen
        } else {
            addressTypeImage.image = UIImage(systemName: "questionmark.circle")
            addressTypeLabel.text = "Unknown address:"
            addressTypeImage.tintColor = .systemRed
        }
        
        return cell
    }
    
    private func feeCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "feeCell", for: indexPath)
        configureCell(cell)
        
        let feeLabel = cell.viewWithTag(1) as! UILabel
        if let fee = psbt.fee {
            feeLabel.text = "\((Double(fee) / 100000000.0).avoidNotation) btc / \(fee) sats"
        } else {
            feeLabel.text = "No fee available..."
        }
        
        return cell
    }
    
    private func labelCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath)
        configureCell(cell)
        
        let label = cell.viewWithTag(1) as! UILabel
        label.text = psbtStruct.label
        
        let editButton = cell.viewWithTag(2) as! UIButton
        editButton.addTarget(self, action: #selector(editLabelMemo(_:)), for: .touchUpInside)
        
        return cell
    }
    
    private func memoCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath)
        configureCell(cell)
        
        let label = cell.viewWithTag(1) as! UILabel
        label.text = psbtStruct.memo
        
        let editButton = cell.viewWithTag(2) as! UIButton
        editButton.addTarget(self, action: #selector(editLabelMemo(_:)), for: .touchUpInside)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
         if tableView.tag == 3 {
            return 90
         } else {
            switch indexPath.section {
            case 0:
                return 61
            case 1:
                return 150
            case 2:
                return 44
            case 3:
                return 445
            case 4:
                return 271
            case 5:
                return 44
            default:
                return 80
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if tableView.tag == 3 {
            return 0
        } else {
            return 50
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if tableView.tag != 3 {
            let header = UIView()
            header.backgroundColor = UIColor.clear
            header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
            
            let textLabel = UILabel()
            textLabel.textAlignment = .left
            textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
            textLabel.textColor = .white
            textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
            
            switch section {
            case 0:
                textLabel.text = "Label"
            case 1:
                textLabel.text = "Memo"
            case 2:
                textLabel.text = "Status"
            case 3:
                textLabel.text = "Inputs"
            case 4:
                textLabel.text = "Outputs"
            case 5:
                textLabel.text = "Mining Fee"
            default:
                break
            }
            
            header.addSubview(textLabel)
            return header
        } else {
            return nil
        }
    }
    
    @objc func addCosigner(_ sender: UIButton) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToAddSignerFromPsbt", sender: self)
        }
    }
    
    @objc func editLabelMemo(_ sender: UIButton) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "editPaymentLabel", sender: self)
        }
    }
    
    private func sign() {
        spinner.add(vc: self, description: "signing")
        
        PSBTSigner.sign(psbt.description) { [weak self] (signedPsbt, signedFor, errorMessage) in
            guard let self = self else { return }
                        
            guard let signedPsbt = signedPsbt, let signedFor = signedFor else {
                showAlert(self, "Something is not right...", errorMessage ?? "unable to sign that psbt: unknown error")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.signedFor = signedFor
                self.save(signedPsbt)
                self.psbt = signedPsbt
                self.signButtonOutlet.alpha = 0
                
                self.load { success in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.tableView.reloadData()
                        self.spinner.remove()
                        showAlert(self, "Payment Signed ✓", "The signed payment has been saved. Export it by tapping the share button in top right.")
                    }
                }
            }
        }
    }
    
    private func save(_ psbtToSave: PSBT) {
        CoreDataService.updateEntity(id: self.psbtStruct.id, keyToUpdate: "psbt", newValue: psbtToSave.data, entityName: .payment) { (success, errorDescription) in
            guard success else {
                showAlert(self, "Not saved!", "There was an issue saving the updated psbt. Please reach out and let us know. Error: \(errorDescription ?? "unknown")")
                
                return
            }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .psbtSaved, object: nil, userInfo: nil)
            }
        }
    }
    
    private func exportAsFile(_ psbt: Data) {
        guard let url = exportPsbtToURL(data: psbt) else {
            showAlert(self, "Ooops", "We had an issue converting that psbt to raw data.")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = self.view
                activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
            }
            
            self.present(activityViewController, animated: true) {}
        }
    }
    
    public func exportPsbtToURL(data: Data) -> URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let path = documents?.appendingPathComponent("/\(psbtStruct.label).psbt") else {
            return nil
        }
        
        do {
            try data.write(to: path, options: .atomicWrite)
            return path
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
        
    private func exportAction() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Export", message: "", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: ".psbt file", style: .default, handler: { action in
                self.exportAsFile(self.psbt.data)
            }))
            
            alert.addAction(UIAlertAction(title: "psbt base64 text", style: .default, handler: { action in
                //print("psbt to export: \(self.psbt.description)")
                self.exportText(self.psbt.description)
            }))
            
            alert.addAction(UIAlertAction(title: "crypto-psbt UR QR", style: .default, handler: { action in
                self.exportAsQR()
            }))
            
            if self.rawTx != "" {
                alert.addAction(UIAlertAction(title: "raw transaction text", style: .default, handler: { action in
                    self.exportText(self.rawTx)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }
    
    private func exportAsQR() {
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "segueToQRDisplayer", sender: self)
        }
    }
    
    private func exportText(_ text: String) {
        DispatchQueue.main.async {
            let textToShare = [text]
            let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = self.view
                activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
            }
            
            self.present(activityViewController, animated: true) {}
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToAddSignerFromPsbt" {
            if let vc = segue.destination as? KeysetsViewController {
                vc.isAdding = true
            }
        }
        if segue.identifier == "segueToQRDisplayer" {
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.text = psbt.description
                vc.isPsbt = true
            }
        }
        
        if segue.identifier == "segueToSign" {
            if let vc = segue.destination as? AddSignerViewController {
                vc.tempWords = true
                
                vc.doneBlock = { [weak self] in
                    guard let self = self else { return }
                    
                    self.showAuth()
                }
            }
        }
        
        if segue.identifier == "editPaymentLabel" {
            if let vc = segue.destination as? LabelMemoViewController {
                vc.psbtStruct = self.psbtStruct
                vc.doneBlock = { [weak self] in
                    guard let self = self else { return }
                    
                    CoreDataService.retrieveEntity(entityName: .payment) { (payments, errorDescription) in
                        guard let payments = payments else { return }
                        
                        for payment in payments {
                            let paymentStruct =  PsbtStruct(dictionary: payment)
                            if paymentStruct.id == self.psbtStruct.id {
                                self.psbtStruct = paymentStruct
                                self.loadTable()
                                
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(name: .psbtSaved, object: nil, userInfo: nil)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: AUTH
    private func showAuth() {
        if UserDefaults.standard.object(forKey: "userIdentifier") != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let request = ASAuthorizationAppleIDProvider().createRequest()
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.performSegue(withIdentifier: "segueToAuth", sender: self)
            }
        }
    }
        
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let username = UserDefaults.standard.object(forKey: "userIdentifier") as? String {
            switch authorization.credential {
            case _ as ASAuthorizationAppleIDCredential:
                let authorizationProvider = ASAuthorizationAppleIDProvider()
                authorizationProvider.getCredentialState(forUserID: username) { [weak self] (state, error) in
                    guard let self = self else { return }
                    
                    switch (state) {
                    case .authorized:
                        self.sign()
                    case .revoked:
                        print("No Account Found")
                        fallthrough
                    case .notFound:
                        print("No Account Found")
                    default:
                        break
                    }
                }
            default:
                break
            }
        }
    }
}
