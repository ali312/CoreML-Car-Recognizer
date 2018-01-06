//
//  ViewController.swift
//  CoreML Car Recognizer
//
//  Created by Anton Kuznetsov on 06.01.18.
//  Copyright © 2018 Anton Kuznetsov. All rights reserved.
//

import MobileCoreServices
import Vision
import CoreML
import AVKit

import UIKit

class ViewController: UIViewController {
    @IBOutlet var cameraView: UIView!
    @IBOutlet var carLabel: UILabel!
    
    var cameraLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewSetup()
        cameraSetup()
    }
    
    func viewSetup() {
        cameraView.layer.cornerRadius = 10
        cameraView.layer.masksToBounds = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraLayer.frame = cameraView.bounds
    }
    
    func cameraSetup() {
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)!
        let input = try! AVCaptureDeviceInput(device: backCamera)
        captureSession.addInput(input)
        
        cameraLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        cameraLayer.videoGravity = .resizeAspectFill
        cameraView.layer.addSublayer(cameraLayer)
        cameraLayer.frame = cameraView.bounds
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "buffer delegate"))
        videoOutput.recommendedVideoSettings(forVideoCodecType: .jpeg, assetWriterOutputFileType: .mp4)
        
        captureSession.addOutput(videoOutput)
        captureSession.sessionPreset = .high
        captureSession.startRunning()
    }
    
    func predict(image: CGImage) {
        let model = try! VNCoreMLModel(for: CarRecognition().model)
        let request = VNCoreMLRequest(model: model, completionHandler: results)
        let handler = VNSequenceRequestHandler()
        try! handler.perform([request], on: image)
    }
    
    func results(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation] else {
            print("No result found")
            return
        }
        
        guard results.count != 0 else {
            print("No result found")
            return
        }
        
        let highestConfidenceResult = results.first!
        
        carLabel.text = highestConfidenceResult.identifier
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { fatalError("pixel buffer is nil") }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        
        guard var cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { fatalError("cg image") }
        var uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .leftMirrored)
        
        let oldWidth = uiImage.size.width
        let scaleFactor = 224 / oldWidth
        
        let newHeight = uiImage.size.height * scaleFactor
        let newWidth = oldWidth * scaleFactor
        
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        uiImage.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        cgImage = (newImage?.cgImage?.cropping(to: CGRect(x: 0, y: 0, width: 224, height: 224)))!
        
        uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .leftMirrored)
        
        DispatchQueue.main.sync {
            predict(image: uiImage.cgImage!)
        }
    }
}
