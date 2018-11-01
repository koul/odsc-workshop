//
//  CameraHelper.swift
//  MacCameraApp
//
//  Created by Meher Kasam on 10/31/18.
//  Copyright © 2018 Conference. All rights reserved.
//

import AVFoundation
import AppKit

protocol CameraFrameDelegate: class {
    func frameCaptured(_ frame: NSImage)
}

class CameraHelper: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var delegate: CameraFrameDelegate?
    
    private var captureDevice: AVCaptureDevice!
    private var captureSession: AVCaptureSession!
    private var input: AVCaptureDeviceInput!
    private var videoOutput: AVCaptureVideoDataOutput!
    private let queue = DispatchQueue(label: "camera-frames")
    var permissionGrantedForCamera: Bool = false
    
    private override init() {}
    
    convenience init?(_ cameraPosition: AVCaptureDevice.Position) {
        self.init()
        self.captureSession = AVCaptureSession()
        self.captureSession.sessionPreset = .medium
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.permissionGrantedForCamera = true
            self.startCapture()
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                self?.permissionGrantedForCamera = granted
                
                if granted {
                    self?.startCapture()
                }
            }
        default:
            self.permissionGrantedForCamera = false
        }
    }
    
    func startCapture()
    {
        guard self.permissionGrantedForCamera else { return }
        
        self.captureDevice = AVCaptureDevice.default(for: .video)
        
        do {
            try self.input = AVCaptureDeviceInput(device: self.captureDevice)
        } catch {
            // handle exception here
        }
        
        if self.captureSession.canAddInput(self.input) {
            self.captureSession.addInput(self.input)
        }
        
        self.videoOutput = AVCaptureVideoDataOutput()
        self.videoOutput.setSampleBufferDelegate(self, queue: self.queue)
        
        if self.captureSession.canAddOutput(self.videoOutput) {
            self.captureSession.addOutput(self.videoOutput)
        }
        
        let connection = self.videoOutput.connection(with: .video)
        connection?.videoOrientation = .portrait
        connection?.isVideoMirrored = false
        
        self.captureSession.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let image = self.imageFromSampleBuffer(buffer: sampleBuffer) else { return }
        self.delegate?.frameCaptured(image)
    }
    
    func imageFromSampleBuffer(buffer: CMSampleBuffer) -> NSImage? {
        guard let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        let width = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        let imageRect: CGRect = CGRect(x: 0, y: 0, width: width, height: height)
        let ciContext = CIContext.init()
        guard let cgImage = ciContext.createCGImage(ciImage, from: imageRect) else { return nil }
        
        let image = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        return image
    }
}
