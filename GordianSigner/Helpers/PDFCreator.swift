//
//  PDFCreator.swift
//  GordianSigner
//
//  Created by Peter Denton on 3/17/21.
//  Copyright © 2021 Blockchain Commons. All rights reserved.
//

import Foundation
import UIKit
import PDFKit

class PDFCreator {
    static var shared = PDFCreator()
    
    var cosigners:[CosignerStruct] = []
    
    lazy var pageWidth : CGFloat  = {
        return 8.5 * 72.0
    }()
    
    lazy var pageHeight : CGFloat = {
        return 11 * 72.0
    }()
    
    lazy var pageRect : CGRect = {
        CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    }()
    
    lazy var marginPoint : CGPoint = {
        return CGPoint(x: 10, y: 10)
    }()
    
    lazy var marginSize : CGSize = {
        return CGSize(width: self.marginPoint.x * 2 , height: self.marginPoint.y * 2)
    }()
    
    
    func prepareData() -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "Gordian Cosigner",
            kCGPDFContextAuthor: "Blockchain Commons LLC",
            kCGPDFContextTitle: "Cosigner Backup"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let qrGenerator = QRGenerator()
        
        let data = renderer.pdfData { (context) in
            
            for cosigner in cosigners {
                self.addText(" \(cosigner.label)", context: context)
                let lifehash = LifeHash.image(cosigner.lifehash)
                addLifehash(image: lifehash!, pageRect: pageRect, imageTop: 1.0)
                
                if let ur = URHelper.cosignerToUr(cosigner.bip48SegwitAccount!, false),
                   let qr = qrGenerator.getQRCode(ur) {
                    addQR(image: qr, pageRect: pageRect, imageTop: 2.0)
                }
                
            }
        }
        
        return data
    }
    
    func addText(_ text : String, context : UIGraphicsPDFRendererContext) {
        let textFont = UIFont.systemFont(ofSize: 40.0, weight: .regular)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .natural
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let textAttributes = [
            NSAttributedString.Key.paragraphStyle: paragraphStyle,
            NSAttributedString.Key.font: textFont
        ]
        
        let currentText = CFAttributedStringCreate(nil,
                                                   text as CFString,
                                                   textAttributes as CFDictionary)
        
        let framesetter = CTFramesetterCreateWithAttributedString(currentText!)
        
        var currentRange = CFRangeMake(0, 0)
        var currentPage = 0
        var done = false
        repeat {
            
            /* Mark the beginning of a new page.*/
            context.beginPage()
            
            /*Draw a page number at the bottom of each page.*/
            currentPage += 1
            drawPageNumber(currentPage)
            
            /*Render the current page and update the current range to
             point to the beginning of the next page. */
            currentRange = renderPage(currentPage,
                                      withTextRange: currentRange,
                                      andFramesetter: framesetter)
            
            /* If we're at the end of the text, exit the loop. */
            if currentRange.location == CFAttributedStringGetLength(currentText) {
                done = true
            }
            
        } while !done
    }
    
    func addBodyText(pageRect: CGRect, textTop: CGFloat) {
      let textFont = UIFont.systemFont(ofSize: 12.0, weight: .regular)
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.alignment = .natural
      paragraphStyle.lineBreakMode = .byWordWrapping
        
      let textAttributes = [
        NSAttributedString.Key.paragraphStyle: paragraphStyle,
        NSAttributedString.Key.font: textFont
      ]
        
      let attributedText = NSAttributedString(
        string: "Keep this QR code somewhere safe, you can use it to recover your Cosigner.",
        attributes: textAttributes
      )
        
      let textRect = CGRect(
        x: 10,
        y: textTop,
        width: pageRect.width - 20,
        height: pageRect.height - textTop - pageRect.height / 5.0
      )
        
      attributedText.draw(in: textRect)
    }
    
    func addLifehash(image: UIImage, pageRect: CGRect, imageTop: CGFloat) {
        let maxHeight = pageRect.height * 0.2
        let maxWidth = pageRect.width * 0.4
        let aspectWidth = maxWidth / image.size.width
        let aspectHeight = maxHeight / image.size.height
        let aspectRatio = min(aspectWidth, aspectHeight)
        let scaledWidth = image.size.width * aspectRatio
        let scaledHeight = image.size.height * aspectRatio
        let imageRect = CGRect(x: pageRect.midX - (scaledWidth / 2), y: 500, width: scaledWidth, height: scaledHeight)
        image.draw(in: imageRect)
    }
    
    func addQR(image: UIImage, pageRect: CGRect, imageTop: CGFloat) {
        let maxHeight = pageRect.height * 0.4
        let maxWidth = pageRect.width * 0.8
        let aspectWidth = maxWidth / image.size.width
        let aspectHeight = maxHeight / image.size.height
        let aspectRatio = min(aspectWidth, aspectHeight)
        let scaledWidth = image.size.width * aspectRatio
        let scaledHeight = image.size.height * aspectRatio
        let imageX = (pageRect.width - scaledWidth) / 2.0
        let imageRect = CGRect(x: imageX, y: 100, width: scaledWidth, height: scaledHeight)
        image.draw(in: imageRect)
    }
    
    func renderPage(_ pageNum: Int, withTextRange currentRange: CFRange, andFramesetter framesetter: CTFramesetter?) -> CFRange {
        var currentRange = currentRange
        // Get the graphics context.
        let currentContext = UIGraphicsGetCurrentContext()
        
        // Put the text matrix into a known state. This ensures
        // that no old scaling factors are left in place.
        currentContext?.textMatrix = .identity
        
        // Create a path object to enclose the text. Use 72 point
        // margins all around the text.
        let frameRect = CGRect(x: self.marginPoint.x, y: self.marginPoint.y, width: self.pageWidth - self.marginSize.width, height: self.pageHeight - self.marginSize.height)
        let framePath = CGMutablePath()
        framePath.addRect(frameRect, transform: .identity)
        
        // Get the frame that will do the rendering.
        // The currentRange variable specifies only the starting point. The framesetter
        // lays out as much text as will fit into the frame.
        let frameRef = CTFramesetterCreateFrame(framesetter!, currentRange, framePath, nil)
        
        // Core Text draws from the bottom-left corner up, so flip
        // the current transform prior to drawing.
        currentContext?.translateBy(x: 0, y: self.pageHeight)
        currentContext?.scaleBy(x: 1.0, y: -1.0)
        
        // Draw the frame.
        CTFrameDraw(frameRef, currentContext!)
        
        // Update the current range based on what was drawn.
        currentRange = CTFrameGetVisibleStringRange(frameRef)
        currentRange.location += currentRange.length
        currentRange.length = CFIndex(0)
        
        return currentRange
    }
    
    func drawPageNumber(_ pageNum: Int) {
        
        let theFont = UIFont.systemFont(ofSize: 12)
        
        let pageString = NSMutableAttributedString(string: "Keep this QR code somewhere safe, you can use it to recover your Cosigner.")
        pageString.addAttribute(NSAttributedString.Key.font, value: theFont, range: NSRange(location: 0, length: pageString.length))
        
        let pageStringSize =  pageString.size()
        
        let stringRect = CGRect(x: (pageRect.width - pageStringSize.width) / 2.0,
                                y: pageRect.height - (pageStringSize.height) / 2.0 - 15,
                                width: pageStringSize.width,
                                height: pageStringSize.height)
        
        pageString.draw(in: stringRect)
        
    }
}
