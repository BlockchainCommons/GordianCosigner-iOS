//
//  LabelMemoViewController.swift
//  GordianSigner
//
//  Created by Peter on 1/23/21.
//  Copyright © 2021 Blockchain Commons. All rights reserved.
//

import UIKit

class LabelMemoViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
    
    @IBOutlet weak var labelField: UITextField!
    @IBOutlet weak var memoField: UITextView!
    
    var psbtStruct:PsbtStruct!
    var doneBlock:(() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        memoField.delegate = self
        memoField.layer.cornerRadius = 8
        memoField.layer.borderWidth = 0.5
        memoField.layer.borderColor = UIColor.lightGray.cgColor
        
        labelField.delegate = self
        labelField.layer.borderWidth = 0.5
        labelField.layer.cornerRadius = 8
        labelField.layer.borderColor = UIColor.lightGray.cgColor
        
        labelField.text = psbtStruct.label
        memoField.text = psbtStruct.memo
        
        addTapGesture()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        update()
    }
    
    private func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        labelField.resignFirstResponder()
        memoField.resignFirstResponder()
    }
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.dismiss(animated: true) {
                self.doneBlock!()
            }
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        textView.resignFirstResponder()
    }
        
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    private func update() {
        CoreDataService.updateEntity(id: psbtStruct.id, keyToUpdate: "label", newValue: labelField.text ?? "", entityName: .payment) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            guard success else { showAlert(self, "", "Label not updated!"); return }
            
            CoreDataService.updateEntity(id: self.psbtStruct.id, keyToUpdate: "memo", newValue: self.memoField.text ?? "", entityName: .payment) { (success, errorDescription) in
                guard success else { showAlert(self, "", "Memo not updated!"); return }
            }
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
