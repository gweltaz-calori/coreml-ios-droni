//
//  ViewController.swift
//  Droooni
//
//  Created by Gweltaz calori on 02/02/2019.
//  Copyright © 2019 Gweltaz calori. All rights reserved.
//

import UIKit
import CoreML
import Vision
import ImageIO

extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        return CGPoint(x: self.x * size.width, y: self.y * size.height)
    }
}
extension CGRect {
    func scaled(to size: CGSize) -> CGRect {
        return CGRect(
            x: self.origin.x * size.width,
            y: self.origin.y * size.height,
            width: self.size.width * size.width,
            height: self.size.height * size.height
        )
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        }
    }
}

class ViewController: UIViewController {
    
    @IBOutlet weak var classificationLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    var inputImage: CIImage?
    
    var nmsThreshold: Float = 0.5

    @IBAction func click(_ sender: Any) {
        performSegue(withIdentifier: "cameraId", sender: self)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let image = UIImage(contentsOfFile: Bundle.main.path(forResource: "dji9", ofType: "jpg")!) else {
            return
        }
        guard let ciImage = CIImage(image: image)
            else { fatalError("can't create CIImage from UIImage") }
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        
        inputImage = ciImage.oriented(forExifOrientation: Int32(orientation.rawValue))
        
        imageView.image = image
        
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([self.detectionRequest])
            } catch {
                print(error)
            }
        }
    }

    lazy var detectionRequest: VNCoreMLRequest = {
        // Load the ML model through its generated class and create a Vision request for it.
        do {
            let model = try VNCoreMLModel(for: SparkClassifier().model)
            
            return VNCoreMLRequest(model: model, completionHandler: self.handleDetection)
        } catch {
            fatalError("can't load Vision ML model: \(error)")
        }
    }()
    
    func handleDetection(request: VNRequest, error: Error?) {
        
        guard let results = request.results else { return }
        
        print(results)
        
        for case let foundObject as VNRecognizedObjectObservation in results {
            let bestLabel = foundObject.labels.first! // Label with highest confidence
            let objectBounds = foundObject.boundingBox
            
            print(bestLabel.identifier, bestLabel.confidence, objectBounds)
            
            
            
            drawRectangle(detectedRectangle: objectBounds)
        }
        
        
    }
    

    public func drawRectangle(detectedRectangle: CGRect) {
        guard let inputImage = inputImage else {
            return
        }
        // Verify detected rectangle is valid.
        let boundingBox = detectedRectangle.scaled(to: inputImage.extent.size)
        
        
        // Show the pre-processed image
        DispatchQueue.main.async {
            self.imageView.image = self.drawOnImage(source: self.imageView.image!, boundingRect: detectedRectangle)
        }
    }
    
    
    fileprivate func drawOnImage(source: UIImage,
                                 boundingRect: CGRect) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(source.size, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        context.translateBy(x: source.size.width, y: 0)
        context.scaleBy(x: -1.0, y: 1.0)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        
        let rectWidth = source.size.width * boundingRect.size.width
        let rectHeight = source.size.height * boundingRect.size.height
        
        //draw image
        let rect = CGRect(x: 0, y:0, width: source.size.width, height: source.size.height)
        context.draw(source.cgImage!, in: rect)
        
        
        //draw bound rect
        var fillColor = UIColor.green
        fillColor.setFill()
        context.addRect(CGRect(x: boundingRect.origin.x * source.size.width, y:boundingRect.origin.y * source.size.height, width: rectWidth, height: rectHeight))
        
        //draw overlay
        fillColor = UIColor.red
        fillColor.setStroke()
        context.setLineWidth(12.0)
        context.drawPath(using: CGPathDrawingMode.stroke)
        
        let coloredImg : UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return coloredImg
    }
}

