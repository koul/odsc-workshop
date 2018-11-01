//
//  ViewController.swift
//  MacCameraApp
//
//  Created by Meher Kasam on 10/28/18.
//  Copyright © 2018 Conference. All rights reserved.
//

import Cocoa
import AVFoundation
import CoreML
import Vision

class ViewController: NSViewController, CameraFrameDelegate {
    
    @IBOutlet weak var cameraView: NSImageView!
    @IBOutlet weak var cameraInaccessibleLabel: NSTextField!
    @IBOutlet weak var predictionsLabel: NSTextField!
    private var cameraHelper: CameraHelper?
    private let model: MLModel = MobileNet().model
    private var lastFrameProcessed = Date()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.cameraView.layer?.backgroundColor = CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        self.cameraHelper = CameraHelper(.back)
        
        // if camera helper returned nil, we could not get access to the camera
        // so display a message about it
        self.cameraInaccessibleLabel.isHidden = (self.cameraHelper != nil)
        self.cameraHelper?.delegate = self
    }
    
    func frameCaptured(_ frame: NSImage) {
        DispatchQueue.main.async {
            self.cameraView.image = frame
        }
        
        let currentTime = Date()
        
        if currentTime.timeIntervalSince(self.lastFrameProcessed) * 1000 < 32 {
            //return
        }
        
        self.lastFrameProcessed = currentTime
        
        guard let model = try? VNCoreMLModel(for: self.model) else {
            NSLog("Unable to load ML Model.")
            return
        }
        
        // track when the request is initiated
        let startTime = Date()
        
        let classificationRequest = VNCoreMLRequest(model: model) {
            [weak self] (request, _) in
            if let observations = request.results as? [VNClassificationObservation] {
                // get first 2 results from observations array whose confidence value
                // is greater than 2% and join the results by commas
                let results = observations[..<2].filter { $0.confidence > 0.02 }.map { String(format: "\($0.identifier) - %.0f%%", $0.confidence * 100) }.joined(separator: "\n")
                
                // track when the request is completed
                let endTime = Date()
                
                // measure difference between the two times
                let timeInterval = endTime.timeIntervalSince(startTime)
                
                self?.setPredictionsLabel(results, executionTime: timeInterval)
            }
        }
        
        guard let cgImage = frame.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        try? requestHandler.perform([classificationRequest])
    }
    
    func setPredictionsLabel(_ string: String, executionTime: TimeInterval) {
        DispatchQueue.main.async {
            self.predictionsLabel.stringValue = String(format: "Predictions in %.0f ms:\n%@", executionTime * 1000, string)
        }
        
        print("\(Int(executionTime * 1000))")
    }
}
