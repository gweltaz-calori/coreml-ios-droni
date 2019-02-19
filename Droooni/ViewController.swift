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
    
    var bufferSize: CGSize = .zero
    @IBOutlet weak var classificationLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    var inputImage: CIImage?
    @IBOutlet weak var overlay: UIView!
    private var detectionOverlay: CALayer! = nil
    var rootLayer: CALayer! = nil
    

    @IBAction func click(_ sender: Any) {
        performSegue(withIdentifier: "cameraId", sender: self)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let image = UIImage(contentsOfFile: Bundle.main.path(forResource: "ji10", ofType: "jpg")!) else {
            return
        }
        guard let ciImage = CIImage(image: image)
            else { fatalError("can't create CIImage from UIImage") }
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        
        inputImage = ciImage.oriented(forExifOrientation: Int32(orientation.rawValue))
        
        bufferSize.width = CGFloat(image.size.width)
        bufferSize.height = CGFloat(image.size.height)
        
        imageView.image = image
        
        rootLayer = overlay.layer
        
        setupLayers()
        
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([self.detectionRequest])
            } catch {
                print(error)
            }
        }
    }
    
    func setupLayers() {
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }

    lazy var detectionRequest: VNCoreMLRequest = {
        // Load the ML model through its generated class and create a Vision request for it.
        do {
            let model = try VNCoreMLModel(for: SparkClassifier4().model)
            
            return VNCoreMLRequest(model: model, completionHandler: self.handleDetection)
        } catch {
            fatalError("can't load Vision ML model: \(error)")
        }
    }()
    
    func handleDetection(request: VNRequest, error: Error?) {
        
        guard let results = request.results else { return }
        
        
        for case let objectObservation as VNRecognizedObjectObservation in results {
            
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            
            var shapeLayer = createRoundedRectLayerWithBounds(objectBounds)
            detectionOverlay.addSublayer(shapeLayer)
            
        }
        
        
    }
    
   
    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.borderColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 0, 0, 1])
        shapeLayer.borderWidth = 2.0
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }

    
}

