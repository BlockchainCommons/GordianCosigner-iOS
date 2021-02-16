//
//  SettingsViewController.swift
//  GordianSigner
//
//  Created by Peter Denton on 2/9/21.
//  Copyright © 2021 Blockchain Commons. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController {
    
    
    @IBOutlet weak var toggle: UISegmentedControl!
    

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        switch Keys.coinType {
        case "0":
            toggle.selectedSegmentIndex = 1
        default:
            toggle.selectedSegmentIndex = 0
        }
    }
    
    @IBAction func didToggle(_ sender: Any) {
        print("toggle.selectedSegmentIndex: \(toggle.selectedSegmentIndex)")
        if toggle.selectedSegmentIndex == 0 {
            UserDefaults.standard.setValue("1", forKey: "coinType")
        } else {
            UserDefaults.standard.setValue("0", forKey: "coinType")
        }
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
