//
//  QRScannerViewController.swift
//  GordianSigner
//
//  Created by Peter on 10/6/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit
import URKit

class QRScannerViewController: UIViewController {
    
    var decoder:URDecoder!
    var doneBlock : ((String?) -> Void)?
    let spinner = Spinner()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    let qrImageView = UIImageView()
    var stringURL = String()
    var blurArray = [UIVisualEffectView]()
    let qrScanner = QRScanner()
    var isTorchOn = Bool()

    @IBOutlet weak var scannerView: UIImageView!
    @IBOutlet weak var backgroundView: UIVisualEffectView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressDescriptionLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureScanner()
        spinner.add(vc: self, description: "")
        decoder = URDecoder()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        scanNow()
    }
    
    private func scanNow() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.qrScanner.scanQRCode()
            vc.addScannerButtons()
            vc.scannerView.addSubview(vc.qrScanner.closeButton)
            vc.spinner.remove()
        }
    }
    
    private func configureScanner() {
        
        backgroundView.alpha = 0
        progressView.alpha = 0
        progressDescriptionLabel.alpha = 0
        
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerRadius = 8
        
        scannerView.isUserInteractionEnabled = true
        qrScanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary), for: .touchUpInside)
        qrScanner.keepRunning = true
        qrScanner.vc = self
        qrScanner.imageView = scannerView
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        qrScanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary), for: .touchUpInside)
        qrScanner.torchButton.addTarget(self, action: #selector(toggleTorch), for: .touchUpInside)
        qrScanner.closeButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        isTorchOn = false
    }
    
    func addScannerButtons() {
        addBlurView(frame: CGRect(x: scannerView.frame.maxX - 80, y: scannerView.frame.maxY - 80, width: 70, height: 70), button: qrScanner.uploadButton)
        addBlurView(frame: CGRect(x: 10, y: scannerView.frame.maxY - 80, width: 70, height: 70), button: qrScanner.torchButton)
    }
    
    func didPickImage() {
        let qrString = qrScanner.qrString
        process(text: qrString)
    }
    
    @objc func chooseQRCodeFromLibrary() {
        qrScanner.chooseQRCodeFromLibrary()
    }
    
    func getQRCode() {
        let stringURL = qrScanner.stringToReturn
        process(text: stringURL)
    }
    
    @objc func toggleTorch() {
        if isTorchOn {
            qrScanner.toggleTorch(on: false)
            isTorchOn = false
        } else {
            qrScanner.toggleTorch(on: true)
            isTorchOn = true
        }
    }
    
    private func addBlurView(frame: CGRect, button: UIButton) {
        button.removeFromSuperview()
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.contentView.addSubview(button)
        blurArray.append(blur)
        scannerView.addSubview(blur)
    }
    
    @objc func back() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.qrScanner.avCaptureSession.stopRunning()
            vc.dismiss(animated: true, completion: nil)
        }
    }
    
    private func stopScanning(_ result: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.dismiss(animated: true) {
                self.qrScanner.stopScanner()
                self.qrScanner.avCaptureSession.stopRunning()
                self.doneBlock!(result)
            }
        }
    }
    
    private func process(text: String) {
        // Stop if we're already done with the decode.
        guard decoder.result == nil else {
            guard let result = try? decoder.result?.get(), let psbt = URHelper.psbtUrToBase64Text(result) else { return }
            stopScanning(psbt)
            return
        }

        decoder.receivePart(text.lowercased())
        
        let expectedParts = decoder.expectedPartCount ?? 0
        
        guard expectedParts != 0 else {
            guard let result = try? decoder.result?.get(), let psbt = URHelper.psbtUrToBase64Text(result) else { return }
            stopScanning(psbt)
            return
        }
        
        let percentageCompletion = "\(Int(decoder.estimatedPercentComplete * 100))% complete"
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.blurArray.count > 0 {
                for i in self.blurArray {
                    i.removeFromSuperview()
                }
                self.blurArray.removeAll()
            }
            
            self.progressView.setProgress(Float(self.decoder.estimatedPercentComplete), animated: true)
            self.progressDescriptionLabel.text = percentageCompletion
            self.backgroundView.alpha = 1
            self.progressView.alpha = 1
            self.progressDescriptionLabel.alpha = 1
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
