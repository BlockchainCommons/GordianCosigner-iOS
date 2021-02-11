//
//  AuthViewController.swift
//  GordianSigner
//
//  Created by Peter Denton on 2/11/21.
//  Copyright © 2021 Blockchain Commons. All rights reserved.
//

import UIKit
import AuthenticationServices

class AuthViewController: UIViewController, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding, UINavigationControllerDelegate {

    @IBOutlet weak var authenticateOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.delegate = self
        authenticateOutlet.clipsToBounds = true
        authenticateOutlet.layer.cornerRadius = 8
    }
    
    @IBAction func close(_ sender: Any) {
        dismiss()
    }
    
    private func dismiss() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    
    @IBAction func authenticate(_ sender: Any) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                UserDefaults.standard.setValue(appleIDCredential.user, forKeyPath: "userIdentifier")
                print("userIdentifier set")
                self.dismiss()
            }
        default:
            break
        }
    }
        
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }

}
