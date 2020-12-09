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
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak private var imageView: UIImageView!
    @IBOutlet weak var animateOutlet: UIButton!
    
    @IBOutlet weak var shareQrOutlet: UIButton!
    @IBOutlet weak var copyQrOutlet: UIButton!
    @IBOutlet weak var shareTextOutlet: UIButton!
    @IBOutlet weak var copyTextOutlet: UIButton!
    
    var descriptionText = ""
    var header = ""
    private let spinner = Spinner()
    private let qrGenerator = QRGenerator()
    var text = ""
    var isPsbt = false
    private var encoder:UREncoder!
    private var timer: Timer?
    private var parts = [String]()
    private var ur: UR!
    private var partIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        spinner.add(vc: self, description: "")
        headerLabel.text = header
        textView.text = descriptionText
        imageView.isUserInteractionEnabled = true
        
        if isPsbt {
            animateOutlet.alpha = 1
            shareQrOutlet.alpha = 0
            shareTextOutlet.alpha = 0
            copyQrOutlet.alpha = 0
            copyTextOutlet.alpha = 0
            convertToUr()
        } else {
            animateOutlet.alpha = 0
            shareQrOutlet.alpha = 1
            shareTextOutlet.alpha = 1
            copyQrOutlet.alpha = 1
            copyTextOutlet.alpha = 1
            showQR(text)
        }
    }
    
    @IBAction func shareQrAction(_ sender: Any) {
        guard let image = imageView.image else { return }
        
        share(image)
    }
    
    @IBAction func copyQrAction(_ sender: Any) {
        guard let image = imageView.image else { return }
        
        UIPasteboard.general.image = image
        showAlert(self, "", "QR copied ✓")
    }
    
    @IBAction func shareTextAction(_ sender: Any) {
        share(descriptionText)
    }
    
    @IBAction func copyTextAction(_ sender: Any) {
        UIPasteboard.general.string = descriptionText
        showAlert(self, "", "Text copied ✓")
    }
    
    @IBAction func animateAction(_ sender: Any) {
        animateNow()
    }
    
    private func share(_ item: Any) {
        DispatchQueue.main.async {
            let itemToShare = [item]
            let activityViewController = UIActivityViewController(activityItems: itemToShare, applicationActivities: nil)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = self.view
                activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
            }
            
            self.present(activityViewController, animated: true) {}
        }
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
