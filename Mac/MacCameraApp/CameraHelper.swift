//
//  CameraHelper.swift
//  MacCameraApp
//
//  Created by Meher Kasam on 10/31/18.
//  Copyright © 2018 Meher Kasam. All rights reserved.
//

import AVFoundation
import AppKit

protocol CameraFrameDelegate: class {
    func cameraAuthorizationStatusChanged(status: Bool)
    func frameCaptured(_ frame: NSImage)
}

class CameraHelper: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var delegate: CameraFrameDelegate?
    
    private var captureDevice: AVCaptureDevice!
    private var captureSession: AVCaptureSession!
    private var input: AVCaptureDeviceInput!
    private var videoOutput: AVCaptureVideoDataOutput!
    private let queue = DispatchQueue(label: "camera-frames")
    
    override init() {
        super.init()
        self.captureSession = AVCaptureSession()
        self.captureSession.sessionPreset = .medium
        
        if #available(OSX 10.14, *) {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.delegate?.cameraAuthorizationStatusChanged(status: true)
                self.startCapture()
                break
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    self?.delegate?.cameraAuthorizationStatusChanged(status: granted)
                    if granted {
                        self?.startCapture()
                    }
                }
            default:
                self.delegate?.cameraAuthorizationStatusChanged(status: false)
                break
            }
        } else {
            
            self.delegate?.cameraAuthorizationStatusChanged(status: true)
            self.startCapture()
        }
    }
    
    func startCapture() {
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
        let flippedImage = self.flipImageHorizontally(image, width: width, height: height)
        return flippedImage
    }
    
    private func flipImageHorizontally(_ inputImage: NSImage, width: CGFloat, height: CGFloat) -> NSImage {
        let tempImage = NSImage(size: NSSize(width: width, height: height))
        tempImage.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: width, yBy: 0)
        transform.scaleX(by: -1, yBy: 1)
        transform.concat()
        inputImage.draw(at: NSPoint(x: 0, y: 0), from: NSRect(x: 0, y: 0, width: width, height: height), operation: .copy, fraction: 1.0)
        tempImage.unlockFocus()
        
        return tempImage
    }
}
