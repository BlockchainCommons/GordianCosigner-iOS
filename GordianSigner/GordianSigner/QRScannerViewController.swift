//
//  QRScannerViewController.swift
//  GordianSigner
//
//  Created by Peter on 10/6/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class QRScannerViewController: UIViewController {
    
    var doneBlock : ((String?) -> Void)?
    let spinner = Spinner()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    let qrImageView = UIImageView()
    var stringURL = String()
    var blurArray = [UIVisualEffectView]()
    let qrScanner = QRScanner()
    var isTorchOn = Bool()

    @IBOutlet weak var scannerView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configureScanner()
        spinner.add(vc: self, description: "")
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
        scannerView.isUserInteractionEnabled = true
        qrScanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary), for: .touchUpInside)
        qrScanner.keepRunning = false
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
        scannerView.addSubview(blur)
    }
    
    @objc func back() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.qrScanner.avCaptureSession.stopRunning()
            vc.dismiss(animated: true, completion: nil)
        }
    }
    
    private func process(text: String) {
        spinner.add(vc: self, description: "processing...")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.dismiss(animated: true) {
                self.qrScanner.stopScanner()
                self.qrScanner.avCaptureSession.stopRunning()
                self.doneBlock!(text)
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
