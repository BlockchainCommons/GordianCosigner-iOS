//
//  PsbtTableViewController.swift
//  GordianSigner
//
//  Created by Peter on 11/12/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit
import LibWally

class PsbtTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak private var tableView: UITableView!

    var psbt:PSBT!
    var ourFingerprints = [[String:String]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorColor = .lightGray
        getOurFingerprints()
    }
    

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return psbt.inputs.count
        case 1:
            return psbt.outputs.count
        default:
            return 1
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.section {
        case 0:
            return inputCell(indexPath)
        case 1:
            return outputCell(indexPath)
        case 2:
            return feeCell(indexPath)
        default:
            return UITableViewCell()
        }
    }
    
    private func configureCell(_ cell: UITableViewCell) {
        cell.clipsToBounds = true
        cell.layer.cornerRadius = 8
        cell.selectionStyle = .none
    }
    
    private func configureView(_ view: UIView) {
        view.clipsToBounds = true
        view.layer.cornerRadius = 8
    }
    
    private func inputCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "inputCell", for: indexPath)
        configureCell(cell)
        
        let isMineImageView = cell.viewWithTag(1) as! UIImageView
        let amountLabel = cell.viewWithTag(2) as! UILabel
        let participantsTextView = cell.viewWithTag(3) as! UITextView
        let validSignersTextView = cell.viewWithTag(5) as! UITextView
        let numberOfSigsLabel = cell.viewWithTag(6) as! UILabel
        let inputNumberLabel = cell.viewWithTag(7) as! UILabel
        
        inputNumberLabel.text = "Input #\(indexPath.row + 1)"
        
        configureView(isMineImageView)
        configureView(participantsTextView)
        configureView(validSignersTextView)
        
        let input = psbt.inputs[indexPath.row]
        
        if let amount = input.amount {
            amountLabel.text = "\(Double(amount) / 100000000.0) btc"
        }
        
        let (can, signers) = canSign(input)
        
        if can {
            isMineImageView.image = UIImage(systemName: "person.crop.circle.fill.badge.checkmark")
            isMineImageView.tintColor = .systemGreen
        } else {
            isMineImageView.image = UIImage(systemName: "person.crop.circle.fill.badge.xmark")
            isMineImageView.tintColor = .systemPink
        }
        
        validSignersTextView.text = ""
        
        if signers.count > 0 {
            for signer in signers {
                validSignersTextView.text += signer + "\n"
            }
        }
        
        return cell
    }
    
    private func outputCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "outputCell", for: indexPath)
        configureCell(cell)
        
        let outputLabel = cell.viewWithTag(1) as! UILabel
        let isMineImageView = cell.viewWithTag(2) as! UIImageView
        let amountLabel = cell.viewWithTag(3) as! UILabel
        let addressLabel = cell.viewWithTag(4) as! UILabel
        
        let output = psbt.outputs[indexPath.row]
        
        outputLabel.text = "Output #\(indexPath.row + 1)"
        
        isMineImageView.image = UIImage(systemName: "person.crop.circle.fill.badge.checkmark")
        isMineImageView.tintColor = .systemGreen
        
        amountLabel.text = (Double(output.txOutput.amount) / 100000000.0).avoidNotation + " btc"
        
        if let address = output.txOutput.address {
            addressLabel.text = address
        } else {
            addressLabel.text = "no address..."
        }
        
        addressLabel.adjustsFontSizeToFitWidth = true
        
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
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return 168
        case 1:
            return 107
        case 2:
            return 44
        default:
            return 80
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
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
            textLabel.text = "Inputs"
        case 1:
            textLabel.text = "Outputs"
        case 2:
            textLabel.text = "Mining Fee"
        default:
            break
        }
        
        header.addSubview(textLabel)
        return header
    }
    
//    func parse() {
//
//        let inputs = psbt.inputs
//        let outputs = psbt.outputs
//
//        for input in inputs {
//            if let origins = input.origins {
//                for origin in origins {
//                    let path = origin.value.path
//                    print("input path: \(path.description)")
//
//                    let key = origin.key
//                    print("input pubKey: \(key.data.hexString)")
//                }
//            } else {
//                print("no input origins available")
//            }
//
//            if let satoshis = input.amount {
//                print("input satoshis: \(satoshis)")
//            }
//        }
//
//        for output in outputs {
//            if let origins = output.origins {
//                for origin in origins {
//                    let path = origin.value.path
//                    print("output path: \(path.description)")
//
//                    let key = origin.key
//                    print("output pubKey: \(key.data.hexString)")
//                }
//            }
//
//            let satoshis = output.txOutput.amount
//            print("output satoshis: \(satoshis)")
//
//            if let address = output.txOutput.address {
//                print("output address: \(address.description)")
//            }
//        }
//    }
    
    private func getOurFingerprints() {
        CoreDataService.retrieveEntity(entityName: .signer) { (signers, errorDescription) in
            guard let signers = signers, signers.count > 0 else { return }
            
            for signer in signers {
                let signerStruct = SignerStruct(dictionary: signer)
                let dict = ["xfp": signerStruct.fingerprint, "label": signerStruct.label]
                self.ourFingerprints.append(dict)
            }
            
            self.tableView.reloadData()
        }
    }
    
    private func canSign(_ input: PSBTInput) -> (canSign: Bool, signer: [String]) {
        var canSign = false
        var signers = [String]()
        if let origins = input.origins {
            for origin in origins {
                let xfp = origin.value.fingerprint.hexString
                for dict in ourFingerprints {
                    let ourXfp = dict["xfp"]!
                    let label = dict["label"]!
                    if xfp == ourXfp {
                        canSign = true
                        signers.append(label)
                    }
                }
            }
        }
        return (canSign, signers)
    }

}
