// BallDetectionService.swift
// Handles camera feed, ball hit detection, and putter face recognition

import Foundation
import AVFoundation
import Vision
import CoreML
import UIKit
import SwiftUI
import Combine

class BallDetectionService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // MARK: - Published State
    @Published var isSessionRunning = false
    @Published var detectionState: DetectionState = .idle
    @Published var debugMotionValue: Float = 0  // For debugging
    @Published var isBaselineReady = false      // For debugging
    
    enum DetectionState {
        case idle
        case watchingForBall
        case detectingPutter
    }
    
    // MARK: - Callbacks
    var onBallHit: (() -> Void)?
    var onPutterResult: ((Bool) -> Void)?  // true = made, false = miss
    
    // MARK: - Camera
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let processingQueue = DispatchQueue(label: "video.processing.queue")
    
    // MARK: - Ball Detection
    private var ballRegion: CGRect = CGRect(x: 0.25, y: 0.55, width: 0.5, height: 0.35) // Lower center where ball sits
    private var baselineFrame: CVPixelBuffer?
    private var isBaselineSet = false
    private var framesSinceBaseline = 0
    private let motionThreshold: Float = 0.08  // Sensitivity for detecting ball hit (lowered)
    private var consecutiveMotionFrames = 0
    private let requiredMotionFrames = 3  // Frames of motion to confirm hit
    
    // MARK: - Putter Detection
    private var putterModel: VNCoreMLModel?
    private var isPutterDetectionActive = false
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupCamera()
        loadPutterModel()
    }
    
    // MARK: - Camera Setup
    private func setupCamera() {
        captureSession.sessionPreset = .hd1280x720
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No back camera available")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            
            // Set orientation
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }
            
        } catch {
            print("Camera setup error: \(error)")
        }
    }
    
    // MARK: - Putter Model
    private func loadPutterModel() {
        // Try to load custom putter model from bundle
        // User will add their trained "PutterClassifier.mlmodelc" to the project
        
        guard let modelURL = Bundle.main.url(forResource: "PutterClassifier", withExtension: "mlmodelc") else {
            print("PutterClassifier model not found - putter detection will use fallback")
            return
        }
        
        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            putterModel = try VNCoreMLModel(for: mlModel)
            print("Putter model loaded successfully")
        } catch {
            print("Failed to load putter model: \(error)")
        }
    }
    
    // MARK: - Session Control
    func startSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = true
                self?.detectionState = .watchingForBall
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
                self?.detectionState = .idle
            }
        }
    }
    
    // MARK: - Ball Detection Control
    func resetBallDetection() {
        isBaselineSet = false
        baselineFrame = nil
        framesSinceBaseline = 0
        consecutiveMotionFrames = 0
        detectionState = .watchingForBall
    }
    
    // MARK: - Putter Detection Control
    func startPutterDetection() {
        isPutterDetectionActive = true
        detectionState = .detectingPutter
    }
    
    func stopPutterDetection() {
        isPutterDetectionActive = false
    }
    
    // MARK: - Frame Processing
    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        switch detectionState {
        case .watchingForBall:
            detectBallMotion(pixelBuffer)
        case .detectingPutter:
            detectPutterFace(pixelBuffer)
        case .idle:
            break
        }
    }
    
    // MARK: - Ball Motion Detection
    private func detectBallMotion(_ pixelBuffer: CVPixelBuffer) {
        // Set baseline after a few frames to stabilize
        if !isBaselineSet {
            framesSinceBaseline += 1
            if framesSinceBaseline > 30 {  // Wait ~1 second at 30fps
                baselineFrame = copyPixelBuffer(pixelBuffer)
                isBaselineSet = true
                DispatchQueue.main.async {
                    self.isBaselineReady = true
                }
            }
            return
        }
        
        guard let baseline = baselineFrame else { return }
        
        // Compare current frame to baseline in the ball region
        let motionAmount = calculateMotion(baseline: baseline, current: pixelBuffer)
        
        DispatchQueue.main.async {
            self.debugMotionValue = motionAmount
        }
        
        if motionAmount > motionThreshold {
            consecutiveMotionFrames += 1
            if consecutiveMotionFrames >= requiredMotionFrames {
                // Ball was hit!
                DispatchQueue.main.async { [weak self] in
                    self?.detectionState = .idle
                    self?.onBallHit?()
                }
                consecutiveMotionFrames = 0
            }
        } else {
            consecutiveMotionFrames = 0
            // Update baseline periodically to handle lighting changes
            framesSinceBaseline += 1
            if framesSinceBaseline > 150 {  // Every ~5 seconds
                baselineFrame = copyPixelBuffer(pixelBuffer)
                framesSinceBaseline = 0
            }
        }
    }
    
    // Copy pixel buffer since they get reused
    private func copyPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        var copy: CVPixelBuffer?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        CVPixelBufferCreate(nil, width, height, format, nil, &copy)
        
        guard let copyBuffer = copy else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(copyBuffer, [])
        
        let srcData = CVPixelBufferGetBaseAddress(pixelBuffer)
        let dstData = CVPixelBufferGetBaseAddress(copyBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        if let src = srcData, let dst = dstData {
            memcpy(dst, src, bytesPerRow * height)
        }
        
        CVPixelBufferUnlockBaseAddress(copyBuffer, [])
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        return copyBuffer
    }
    
    private func calculateMotion(baseline: CVPixelBuffer, current: CVPixelBuffer) -> Float {
        // Lock buffers
        CVPixelBufferLockBaseAddress(baseline, .readOnly)
        CVPixelBufferLockBaseAddress(current, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(baseline, .readOnly)
            CVPixelBufferUnlockBaseAddress(current, .readOnly)
        }
        
        let width = CVPixelBufferGetWidth(current)
        let height = CVPixelBufferGetHeight(current)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(current)
        
        guard let basePtr = CVPixelBufferGetBaseAddress(baseline),
              let currPtr = CVPixelBufferGetBaseAddress(current) else {
            return 0
        }
        
        let baseBuffer = basePtr.assumingMemoryBound(to: UInt8.self)
        let currBuffer = currPtr.assumingMemoryBound(to: UInt8.self)
        
        // Calculate region to analyze (center area where ball likely is)
        let regionX = Int(Float(width) * Float(ballRegion.minX))
        let regionY = Int(Float(height) * Float(ballRegion.minY))
        let regionW = Int(Float(width) * Float(ballRegion.width))
        let regionH = Int(Float(height) * Float(ballRegion.height))
        
        var totalDiff: Float = 0
        var pixelCount: Float = 0
        
        // Sample every 4th pixel for performance
        for y in stride(from: regionY, to: min(regionY + regionH, height), by: 4) {
            for x in stride(from: regionX, to: min(regionX + regionW, width), by: 4) {
                let offset = y * bytesPerRow + x * 4
                
                // Compare RGB values
                let bDiff = abs(Int(baseBuffer[offset]) - Int(currBuffer[offset]))
                let gDiff = abs(Int(baseBuffer[offset + 1]) - Int(currBuffer[offset + 1]))
                let rDiff = abs(Int(baseBuffer[offset + 2]) - Int(currBuffer[offset + 2]))
                
                let diff = Float(bDiff + gDiff + rDiff) / (255.0 * 3.0)
                totalDiff += diff
                pixelCount += 1
            }
        }
        
        return pixelCount > 0 ? totalDiff / pixelCount : 0
    }
    
    // MARK: - Putter Face Detection
    private func detectPutterFace(_ pixelBuffer: CVPixelBuffer) {
        guard isPutterDetectionActive else { return }
        
        if let model = putterModel {
            // Use ML model
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                self?.handlePutterMLResult(request: request, error: error)
            }
            request.imageCropAndScaleOption = .centerCrop
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try? handler.perform([request])
        } else {
            // Fallback: No model loaded - could implement basic detection here
            // For now, just wait for model to be added
        }
    }
    
    private func handlePutterMLResult(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation],
              let topResult = results.first,
              topResult.confidence > 0.7 else {
            return
        }
        
        // Check classification
        let made = topResult.identifier.lowercased().contains("open") ||
                   topResult.identifier.lowercased().contains("face") ||
                   topResult.identifier.lowercased().contains("yes") ||
                   topResult.identifier.lowercased().contains("made")
        
        DispatchQueue.main.async { [weak self] in
            self?.isPutterDetectionActive = false
            self?.onPutterResult?(made)
        }
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        processFrame(pixelBuffer)
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let cameraService: BallDetectionService
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraService.captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
