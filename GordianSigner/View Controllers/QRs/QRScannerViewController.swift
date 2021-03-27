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
    
    var isRunning = false
    var qrString = ""
    let downSwipe = UISwipeGestureRecognizer()
    let uploadButton = UIButton()
    let torchButton = UIButton()
    let imagePicker = UIImagePickerController()
    var avCaptureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer?
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
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.avCaptureSession.isRunning {
                self.avCaptureSession.stopRunning()
            }
            
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    private func scanNow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.scanQRCode()
            self.addScannerButtons()
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
        torchButton.addTarget(self, action: #selector(toggleTorchNow), for: .touchUpInside)
        isTorchOn = false
        
        configureImagePicker()
        configureUploadButton()
        configureTorchButton()
        configureDownSwipe()
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
    
    private func stopScanning(_ result: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.dismiss(animated: true) {
                self.stopScanner()
                self.doneBlock!(result)
            }
        }
    }
    
    private func isAccountMap(_ text: String) -> Bool {
        guard let _ = try? JSONSerialization.jsonObject(with: text.utf8, options: []) as? [String:Any] else { return false }
        
        return true
    }
    
    private func isCryptoSeed(_ text: String) -> Bool {
        return text.lowercased().hasPrefix("ur:crypto-seed/")
    }
    
    private func isCryptoAccount(_ text: String) -> Bool {
        return text.lowercased().hasPrefix("ur:crypto-account/")
    }
    
    private func isCosigner(_ text: String) -> Bool {
        return text.contains("48h/\(Keys.coinType)h/0h/2h")
    }
    
    private func isCryptoHDKey(_ text: String) -> Bool {
        return text.lowercased().hasPrefix("ur:crypto-hdkey/")
    }
    
    private func isMnemonic(_ text: String) -> Bool {
        return Keys.validMnemonicString(processedCharacters(text))
    }
    
    private func isPsbt(_ text: String) -> Bool {
        return text.lowercased().hasPrefix("ur:crypto-psbt/")
    }
    
    private func isCryptoResponse(_ text: String) -> Bool {
        return text.lowercased().hasPrefix("ur:crypto-response/")
    }
    
    private func isSskr(_ text: String) -> Bool {
        return text.lowercased().hasPrefix("ur:crypto-sskr/")
    }
    
    private func isOutput(_ text: String) -> Bool {
        return text.lowercased().hasPrefix("ur:crypto-output/")
    }
    
    private func process(text: String) {
        isRunning = true
        
        if isPsbt(text) {
            //keepRunning = true
            // Stop if we're already done with the decode.
            guard decoder.result == nil else {
                guard let result = try? decoder.result?.get(), let psbt = URHelper.psbtUrToBase64Text(result) else { return }
                stopScanning(psbt)
                return
            }
            
            decoder.receivePart(text.lowercased())
            
            let expectedParts = decoder.expectedPartCount ?? 0
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if self.avCaptureSession.isRunning {
                    self.avCaptureSession.stopRunning()
                }
                let impact = UIImpactFeedbackGenerator()
                impact.impactOccurred()
                AudioServicesPlaySystemSound(1103)
            }
            
            guard expectedParts != 0 else {
                guard let result = try? decoder.result?.get(), let psbt = URHelper.psbtUrToBase64Text(result) else { return }
                stopScanning(psbt)
                return
            }
            
            self.isRunning = false
            
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
        } else if isAccountMap(text) || isCryptoAccount(text) || isCosigner(text) || isCryptoHDKey(text) || isMnemonic(text) || isCryptoSeed(text) || isCryptoResponse(text) || isSskr(text) || isOutput(text) {
            DispatchQueue.main.async {
                let impact = UIImpactFeedbackGenerator()
                impact.impactOccurred()
                AudioServicesPlaySystemSound(1103)
                self.stopScanning(text)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if self.avCaptureSession.isRunning {
                    self.avCaptureSession.stopRunning()
                }
                
                let impact = UIImpactFeedbackGenerator()
                impact.impactOccurred()
                AudioServicesPlaySystemSound(1103)
                showAlert(self, "That is not a supported QR code", "Please let us know about it at https://github.com/BlockchainCommons/GordianCosigner-iOS/issues")
            }
        }
    }
    
    @objc func handleSwipes(_ sender: UIGestureRecognizer) {
        stopScanner()
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
        let queue = DispatchQueue(label: "codes", qos: .userInteractive)
        avCaptureSession = AVCaptureSession()
        
        guard let avCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        guard let avCaptureInput = try? AVCaptureDeviceInput(device: avCaptureDevice) else { return }
        
        let avCaptureMetadataOutput = AVCaptureMetadataOutput()
        avCaptureMetadataOutput.setMetadataObjectsDelegate(self, queue: queue)
        
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
        
        guard avCaptureSession.canAddInput(avCaptureInput) else { return }
        avCaptureSession.addInput(avCaptureInput)
        
        guard avCaptureSession.canAddOutput(avCaptureMetadataOutput) else { return }
        avCaptureSession.addOutput(avCaptureMetadataOutput)
        
        avCaptureMetadataOutput.metadataObjectTypes = [.qr]
        previewLayer = AVCaptureVideoPreviewLayer(session: avCaptureSession)
        previewLayer!.videoGravity = .resizeAspectFill
        previewLayer!.frame = self.scannerView.bounds
        self.scannerView.layer.addSublayer(previewLayer!)
        self.avCaptureSession.startRunning()
    }
        
    func stopScanner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.avCaptureSession.isRunning {
                self.avCaptureSession.stopRunning()
            }
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
        if !isRunning {
            guard metadataObjects.count > 0,
                let machineReadableCode = metadataObjects[0] as? AVMetadataMachineReadableCodeObject,
                machineReadableCode.type == .qr,
                let string = machineReadableCode.stringValue else {
                    isRunning = false
                    return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if self.avCaptureSession.isRunning {
                    self.avCaptureSession.stopRunning()
                }
            }
            
            isRunning = true
            
            process(text: string)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                
                self.avCaptureSession.startRunning()
            }
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
