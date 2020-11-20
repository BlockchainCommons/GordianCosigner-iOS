//
//  CreateAccountMapViewController.swift
//  GordianSigner
//
//  Created by Peter on 11/20/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class CreateAccountMapViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    var totalParticipants = 15
    var totalRequiredSigs = 15
    
    @IBOutlet weak var nPickerView: UIPickerView!
    @IBOutlet weak var mPickerView: UIPickerView!
    @IBOutlet weak var createOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        nPickerView.delegate = self
        nPickerView.dataSource = self
        mPickerView.delegate = self
        mPickerView.delegate = self
        nPickerView.isUserInteractionEnabled = true
        mPickerView.isUserInteractionEnabled = true
    }
    
    @IBAction func createAction(_ sender: Any) {
        let m = totalParticipants
        let n = totalRequiredSigs
        
        print("\(m) of \(n)")
        
        var desc = "wsh(sortedmulti(\(m),"
        
        var keystores = ""
        
        for i in 0...n - 1 {
            if i < n - 1 {
                keystores += "<keystore #\(i + 1)>,"
            } else {
               keystores += "<keystore #\(i + 1)>"
            }
        }
        
        desc += keystores + "))"
        
        let accountMap = ["descriptor":desc, "birthblock":0, "label":"Policy Map"] as [String : Any]
        let json = accountMap.json() ?? ""
        
        var map = [String:Any]()
        map["birthblock"] = Int64(0)
        map["accountMap"] = json.utf8
        map["label"] = "Policy Map"
        map["id"] = UUID()
        map["dateAdded"] = Date()
        map["complete"] = false
        map["descriptor"] = desc
        
        CoreDataService.saveEntity(dict: map, entityName: .accountMap) { [weak self] (success, errorDescription) in
            guard let self = self, success else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let alertStyle = UIAlertController.Style.alert
                
                let alert = UIAlertController(title: "Policy Map created ✓", message: "Tap done to go back", preferredStyle: alertStyle)
                
                alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                    DispatchQueue.main.async { [weak self] in
                        self?.navigationController?.popViewController(animated: true)
                    }
                }))
            
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == nPickerView {
            return totalParticipants
        } else {
            return totalRequiredSigs
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let string = "\(row + 1)"
        return NSAttributedString(string: string, attributes: [NSAttributedString.Key.foregroundColor: UIColor.white])
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == nPickerView {
            let row = pickerView.selectedRow(inComponent: component)
            totalRequiredSigs = row + 1
            mPickerView.reloadAllComponents()
        } else {
            totalParticipants = row + 1
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
