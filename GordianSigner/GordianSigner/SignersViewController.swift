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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadData()
    }
    
    @IBAction func addSigner(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToAddASigner", sender: self)
        }
    }
    
    @objc func seeSignerDetail(_ sender: UIButton) {
        
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
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension SignersViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
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
        //let chevron = cell.viewWithTag(2) as! UIButton
        let imageView = cell.viewWithTag(3) as! UIImageView
        let backgroundView = cell.viewWithTag(4)!
        
        cell.selectionStyle = .none
        
        label.text = fingeprints[indexPath.section]
        
        //            chevron.tag = indexPath.section
        //            chevron.addTarget(self, action: #selector(seeSignerDetail(_:)), for: .touchUpInside)
        //            chevron.alpha = 0
        
        //imageView.image = UIImage(systemName: "pencil.and.ellipsis.rectangle")
        imageView.tintColor = .white
        
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerRadius = 5
        backgroundView.backgroundColor = .systemBlue
        return cell
    }
    
}
