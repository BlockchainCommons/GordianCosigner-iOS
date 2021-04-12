//
//  SettingsViewController.swift
//  GordianSigner
//
//  Created by Peter Denton on 2/9/21.
//  Copyright © 2021 Blockchain Commons. All rights reserved.
//

import UIKit
import PDFKit

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
        if toggle.selectedSegmentIndex == 0 {
            UserDefaults.standard.setValue("1", forKey: "coinType")
        } else {
            UserDefaults.standard.setValue("0", forKey: "coinType")
        }
        refreshCosigners()
    }
    
    @IBAction func backupAction(_ sender: Any) {
        CoreDataService.retrieveEntity(entityName: .cosigner) { (cosigners, errorDescription) in
            guard let cosigners = cosigners else { return }
            var cosignerStrArray:[CosignerStruct] = []
            
            for (i, cosigner) in cosigners.enumerated() {
                let cosignerStr = CosignerStruct(dictionary: cosigner)
                cosignerStrArray.append(cosignerStr)
                
                if i + 1 == cosigners.count {
                    let creator = PDFCreator.shared
                    creator.cosigners = cosignerStrArray
                    let pdfData = creator.prepareData()
                    
                    let printController = UIPrintInteractionController.shared
                    let printInfo = UIPrintInfo(dictionary: [:])
                    printInfo.outputType = .general
                    printInfo.orientation = .portrait
                    printInfo.jobName = "Cosigner backup"
                    printController.printInfo = printInfo
                    
                    printController.printingItem = pdfData
                    
                    printController.present(animated: true) { (controller, completed, error) in
                        if(!completed && error != nil){
                            NSLog("Print failed - %@", error!.localizedDescription)
                        }
                        else if(completed) {
                            NSLog("Print succeeded")
                        }
                    }
                }
            }
        }
    }
    
    private func refreshCosigners() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .cosignerAdded, object: nil, userInfo: nil)
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
