//
//  QRScannerViewController.swift
//  GordianSigner
//
//  Created by Peter on 10/6/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit
import URKit
import AVFoundation

class QRScannerViewController: UIViewController {
    
    var qrString = ""
    let downSwipe = UISwipeGestureRecognizer()
    let uploadButton = UIButton()
    let torchButton = UIButton()
    let closeButton = UIButton()
    let imagePicker = UIImagePickerController()
    let avCaptureSession = AVCaptureSession()
    var keepRunning = false
    var decoder:URDecoder!
    var doneBlock : ((String?) -> Void)?
    let spinner = Spinner()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    var stringURL = String()
    var blurArray = [UIVisualEffectView]()
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.scanQRCode()
            self.addScannerButtons()
            self.scannerView.addSubview(self.closeButton)
            self.spinner.remove()
        }
    }
    
    private func configureScanner() {
        
        backgroundView.alpha = 0
        progressView.alpha = 0
        progressDescriptionLabel.alpha = 0
        
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerRadius = 8
        
        scannerView.isUserInteractionEnabled = true
        uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary), for: .touchUpInside)
        uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary), for: .touchUpInside)
        torchButton.addTarget(self, action: #selector(toggleTorchNow), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        isTorchOn = false
        
        configureImagePicker()
        
        #if targetEnvironment(macCatalyst)
        chooseQRCodeFromLibrary()
        
        #else
        configureUploadButton()
        configureTorchButton()
        configureCloseButton()
        configureDownSwipe()
        #endif
    }
    
    func addScannerButtons() {
        addBlurView(frame: CGRect(x: scannerView.frame.maxX - 80, y: scannerView.frame.maxY - 80, width: 70, height: 70), button: uploadButton)
        addBlurView(frame: CGRect(x: 10, y: scannerView.frame.maxY - 80, width: 70, height: 70), button: torchButton)
    }
    
    func didPickImage() {
        process(text: qrString)
    }
    
    @objc func chooseQRCodeFromLibrary() {
        present(imagePicker, animated: true, completion: nil)
    }
    
    func getQRCode() {
        process(text: qrString)
    }
    
    @objc func toggleTorchNow() {
        if isTorchOn {
            toggleTorch(on: false)
            isTorchOn = false
        } else {
            toggleTorch(on: true)
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.avCaptureSession.stopRunning()
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    private func stopScanning(_ result: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.dismiss(animated: true) {
                self.stopScanner()
                self.avCaptureSession.stopRunning()
                self.doneBlock!(result)
            }
        }
    }
    
    private func isAccountMap(_ text: String) -> Bool {
        guard let _ = try? JSONSerialization.jsonObject(with: text.utf8, options: []) as? [String:Any] else { return false }
        
        return true
    }
    
    private func process(text: String) {
        
        if !isAccountMap(text) {
            // Stop if we're already done with the decode.
            guard decoder.result == nil else {
                guard let result = try? decoder.result?.get(), let psbt = URHelper.psbtUrToBase64Text(result) else { return }
                stopScanning(psbt)
                return
            }
            
            decoder.receivePart(text.lowercased())
            
            let expectedParts = decoder.expectedPartCount ?? 0
            
            DispatchQueue.main.async {
                self.avCaptureSession.stopRunning()
                let impact = UIImpactFeedbackGenerator()
                impact.impactOccurred()
                AudioServicesPlaySystemSound(1103)
            }
            
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
            
        } else {
            DispatchQueue.main.async {
                self.avCaptureSession.stopRunning()
                let impact = UIImpactFeedbackGenerator()
                impact.impactOccurred()
                AudioServicesPlaySystemSound(1103)
                self.stopScanning(text)
            }
        }
    }
    
    @objc func handleSwipes(_ sender: UIGestureRecognizer) {
        stopScanner()
    }
    
    func configureCloseButton() {
        closeButton.frame = CGRect(x: view.frame.midX - 15, y: view.frame.maxY - 150, width: 30, height: 30)
        closeButton.setImage(UIImage(systemName: "x.mark.circle"), for: .normal)
        closeButton.tintColor = .systemTeal
    }
    
    func configureTorchButton() {
        torchButton.frame = CGRect(x: 17.5, y: 17.5, width: 35, height: 35)
        torchButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
        torchButton.tintColor = .systemTeal
        addShadow(view: torchButton)
    }
    
    func configureUploadButton() {
        uploadButton.frame = CGRect(x: 17.5, y: 17.5, width: 35, height: 35)
        uploadButton.showsTouchWhenHighlighted = true
        uploadButton.setImage(UIImage(systemName: "photo.fill"), for: .normal)
        uploadButton.tintColor = .systemTeal
        addShadow(view: uploadButton)
    }
    
    func addShadow(view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 1.5, height: 1.5)
        view.layer.shadowRadius = 1.5
        view.layer.shadowOpacity = 0.5
    }
    
    func configureImagePicker() {
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
    }
    
    func configureDownSwipe() {
        downSwipe.direction = .down
        downSwipe.addTarget(self, action: #selector(handleSwipes(_:)))
        scannerView.addGestureRecognizer(downSwipe)
    }
    
    func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        
        if device.hasTorch {
            
            do {
                try device.lockForConfiguration()
                
                if on == true {
                    device.torchMode = .on
                } else {
                    device.torchMode = .off
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
            
        } else {
            print("Torch is not available")
        }
    }
    
    func scanQRCode() {
        guard let avCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        
        guard let avCaptureInput = try? AVCaptureDeviceInput(device: avCaptureDevice) else { return }
        
        let avCaptureMetadataOutput = AVCaptureMetadataOutput()
        avCaptureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        
        if let inputs = avCaptureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                self.avCaptureSession.removeInput(input)
            }
        }
        
        if let outputs = avCaptureSession.outputs as? [AVCaptureMetadataOutput] {
            for output in outputs {
                self.avCaptureSession.removeOutput(output)
            }
        }
        
        avCaptureSession.addInput(avCaptureInput)
        avCaptureSession.addOutput(avCaptureMetadataOutput)
        avCaptureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        let avCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: avCaptureSession)
        avCaptureVideoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        avCaptureVideoPreviewLayer.frame = self.scannerView.bounds
        self.scannerView.layer.addSublayer(avCaptureVideoPreviewLayer)
        self.avCaptureSession.startRunning()
        
    }
        
    func removeScanner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.avCaptureSession.stopRunning()
            self.torchButton.removeFromSuperview()
            self.uploadButton.removeFromSuperview()
            self.scannerView.removeFromSuperview()
        }
    }
    
    func stopScanner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.avCaptureSession.stopRunning()
        }
    }
    
    func startScanner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.avCaptureSession.startRunning()
        }
    }
    
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard metadataObjects.count > 0,
            let machineReadableCode = metadataObjects[0] as? AVMetadataMachineReadableCodeObject,
            machineReadableCode.type == AVMetadataObject.ObjectType.qr,
            let string = machineReadableCode.stringValue else {
                
                return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.avCaptureSession.stopRunning()
        }
        
        process(text: string)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            self.avCaptureSession.startRunning()
        }
    }
    
}

extension QRScannerViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // Local variable inserted by Swift 4.2 migrator.
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        
        guard let pickedImage = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage,
            let detector:CIDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh]),
            let ciImage:CIImage = CIImage(image:pickedImage) else {
                
                return
        }
        
        var qrCodeLink = ""
        let features = detector.features(in: ciImage)
        
        for feature in features as! [CIQRCodeFeature] {
            qrCodeLink += feature.messageString!
        }
        
        DispatchQueue.main.async { [ weak self] in
            guard let self = self else { return }
            
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
            picker.dismiss(animated: true, completion: {
                self.process(text: qrCodeLink)
            })
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            DispatchQueue.main.async {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
}

extension QRScannerViewController: UINavigationControllerDelegate { }

fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
    return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
    return input.rawValue
}
