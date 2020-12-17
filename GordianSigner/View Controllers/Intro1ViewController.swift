//
//  Intro1ViewController.swift
//  GordianSigner
//
//  Created by Peter on 12/17/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class Intro1ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        UserDefaults.standard.set(true, forKey: "seenIntro")
    }
    
    @IBAction func segueTo2(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueTo2", sender: self)
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
