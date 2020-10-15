//
//  QRDisplayerViewController.swift
//  GordianSigner
//
//  Created by Peter on 10/6/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit
import URKit

class QRDisplayerViewController: UIViewController {
    
    @IBOutlet weak private var imageView: UIImageView!
    @IBOutlet weak var animateOutlet: UIButton!
    
    private let spinner = Spinner()
    private let qrGenerator = QRGenerator()
    var text = ""
    private var encoder:UREncoder!
    private var timer: Timer?
    private var parts = [String]()
    private var ur: UR!
    private var partIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        spinner.add(vc: self, description: "")
        convertToUr()
    }
    
    @IBAction func animateAction(_ sender: Any) {
        animateNow()
    }
    
    private func animateNow() {
        animateOutlet.alpha = 0
        encoder = UREncoder(ur, maxFragmentLen: 250)
        setTimer()
    }
    
    private func setTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(automaticRefresh), userInfo: nil, repeats: true)
    }

    @objc func automaticRefresh() {
        nextPart()
    }
    
    private func convertToUr() {
        guard let b64 = Data(base64Encoded: text), let ur = URHelper.psbtUr(b64) else { return }
        self.ur = ur
        let urString = UREncoder.encode(ur)
        showQR(urString)
    }
    
    private func nextPart() {
        let part = encoder.nextPart()
        let index = encoder.seqNum
        
        if index <= encoder.seqLen {
            parts.append(part.uppercased())
        } else {
            timer?.invalidate()
            timer = nil
            timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(animate), userInfo: nil, repeats: true)
        }
    }
    
    @objc func animate() {
        showQR(parts[partIndex])
        
        if partIndex < parts.count - 1 {
            partIndex += 1
        } else {
            partIndex = 0
        }
    }
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    private func showQR(_ urString: String) {
        guard let qr = qrGenerator.getQRCode(urString) else {
            animateNow()
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.imageView.image = qr
            self.spinner.remove()
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
