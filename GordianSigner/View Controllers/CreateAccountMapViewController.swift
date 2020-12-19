//
//  CreateAccountMapViewController.swift
//  GordianSigner
//
//  Created by Peter on 11/20/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class CreateAccountMapViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {
    
    var totalParticipants = 15
    var totalRequiredSigs = 15
    var doneBlock:((String?) -> Void)?
    
    @IBOutlet weak var textField: UITextField!
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
        createOutlet.clipsToBounds = true
        createOutlet.layer.cornerRadius = 8
        textField.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
        textField.removeGestureRecognizer(tapGesture)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        textField.resignFirstResponder()
    }
    
    @IBAction func createAction(_ sender: Any) {
        guard var label = textField.text else {
            showAlert(self, "Add a label first", "Add a label to the Alias field above so you may easily identify this Account, then try again.")
            return
        }
        
        let m = mPickerView.selectedRow(inComponent: 0) + 1
        let n = nPickerView.selectedRow(inComponent: 0) + 1
        
        if label == "" {
            label = "\(m) of \(n)"
        }
        
        var desc = "wsh(sortedmulti(\(m),"
        
        var keystores = ""
        
        for i in 0...n - 1 {
            if i < n - 1 {
                keystores += "<keyset #\(i + 1)>,"
            } else {
               keystores += "<keyset #\(i + 1)>"
            }
        }
        
        desc += keystores + "))"
        
        let accountMap = ["descriptor":desc, "blockheight":0, "label":label] as [String : Any]
        let json = accountMap.json() ?? ""
        
        var map = [String:Any]()
        map["blockheight"] = Int64(0)
        map["accountMap"] = json.utf8
        map["label"] = label
        map["id"] = UUID()
        map["dateAdded"] = Date()
        map["complete"] = false
        map["descriptor"] = desc
        
        CoreDataService.saveEntity(dict: map, entityName: .accountMap) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            guard success else {
                showAlert(self, "Account creation failed", "")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.navigationController?.popViewController(animated: true)
                self?.doneBlock!(json)
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
