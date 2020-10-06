//
//  QRDisplayerViewController.swift
//  GordianSigner
//
//  Created by Peter on 10/6/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class QRDisplayerViewController: UIViewController {
    
    @IBOutlet weak private var imageView: UIImageView!
    
    private let qrGenerator = QRGenerator()
    var text = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        showQR()
    }
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    private func showQR() {
        guard let qr = qrGenerator.getQRCode(text) else {
            showAlert(self, "QR Error", "There is too much data to squeeze into that small of an image")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.imageView.image = qr
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
