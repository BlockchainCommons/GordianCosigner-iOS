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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func addSigner(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToAddASigner", sender: self)
        }
    }
    
    @objc func seeSignerDetail(_ sender: UIButton) {
        
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "signerCell", for: indexPath)
        let label = cell.viewWithTag(1) as! UILabel
        let chevron = cell.viewWithTag(2) as! UIButton
        let imageView = cell.viewWithTag(3) as! UIImageView
        let backgroundView = cell.viewWithTag(4)!
        
        label.text = "some label"
        
        chevron.tag = indexPath.section
        chevron.addTarget(self, action: #selector(seeSignerDetail(_:)), for: .touchUpInside)
        
        imageView.image = UIImage(systemName: "pencil.and.ellipsis.rectangle")
        imageView.tintColor = .white
        
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerRadius = 5
        backgroundView.backgroundColor = .systemBlue
        
        return cell
    }
    
}
