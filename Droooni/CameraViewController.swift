//
//  CameraViewController.swift
//  Droooni
//
//  Created by Gweltaz calori on 02/02/2019.
//  Copyright © 2019 Gweltaz calori. All rights reserved.
//

import UIKit
import Vision
import CoreML
import AVFoundation
class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var requests = [VNRequest]()
    @IBOutlet weak var cameraView: UIView!
    // Create a layer to display camera frames in the UIView
    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    // Create an AVCaptureSession
    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        guard
            let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: backCamera)
            else { return session }
        session.addInput(input)
        return session
    }()
    
    private lazy var classifier: SparkClassifier = SparkClassifier()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraView?.layer.addSublayer(cameraLayer)
        cameraLayer.frame = cameraView.bounds
        
        //        cameraLayer.videoGravity = .resizeAspectFill
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MyQueue"))
        self.captureSession.addOutput(videoOutput)
        self.captureSession.startRunning()
        // Do any additional setup after loading the view.
        
        setupVision()
    }
    
    func setupVision() {
        guard let visionModel = try? VNCoreMLModel(for: classifier.model) else {
            fatalError("Can’t load VisionML model")
        }
        let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: handleClassifications)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.scaleFill
        requests = [classificationRequest]
    }
   
    
    func handleClassifications(request: VNRequest, error: Error?) {
        guard let results = request.results else { return }
        
        for case let foundObject as VNRecognizedObjectObservation in results {
            let bestLabel = foundObject.labels.first! // Label with highest confidence
            let objectBounds = foundObject.boundingBox
            
            print(bestLabel.identifier, bestLabel.confidence, objectBounds)
            
            
            highlight(boundingRect: objectBounds)
        }
        
    }
    
    func highlight(boundingRect: CGRect) {
        let source = self.cameraView.frame
        
        let rectWidth = source.size.width * boundingRect.size.width
        let rectHeight = source.size.height * boundingRect.size.height
        
        let outline = CALayer()
        outline.frame = CGRect(x: boundingRect.origin.x * source.size.width, y:boundingRect.origin.y * source.size.height, width: rectWidth, height: rectHeight)
        
        
        outline.borderWidth = 2.0
        outline.borderColor = UIColor.red.cgColor
        
        self.cameraLayer.addSublayer(outline)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        var requestOptions:[VNImageOption : Any] = [:]
        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics:cameraIntrinsicData]
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: requestOptions)
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }

}
