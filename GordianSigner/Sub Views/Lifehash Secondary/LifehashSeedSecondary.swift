//
//  LifehashSeedSecondary.swift
//  GordianSigner
//
//  Created by Peter on 12/14/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import UIKit

class LifehashSeedSecondary: UIView {

    @IBOutlet weak var iconText: UILabel!
    @IBOutlet weak var iconImage: UIImageView!
    @IBOutlet weak var background: UIView!
    @IBOutlet weak var lifehashImage: UIImageView!
    let nibName = "LifehashSeedSecondary"
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    func commonInit() {
        guard let view = loadViewFromNib() else { return }
        view.frame = self.bounds
        lifehashImage.layer.magnificationFilter = .nearest
        background.clipsToBounds = true
        background.backgroundColor = .clear
        self.addSubview(view)
    }
    
    func loadViewFromNib() -> UIView? {
        let nib = UINib(nibName: nibName, bundle: nil)
        return nib.instantiate(withOwner: self, options: nil).first as? UIView
    }

}
