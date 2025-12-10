import Foundation
import CoreMotion
import AVFoundation
import Combine

class SlopeService: ObservableObject {
    
    // MARK: - Published State
    @Published var isFaceDown: Bool = false
    @Published var isStable: Bool = false
    @Published var isReadyToMeasure: Bool = false
    @Published var currentPitch: Double = 0
    @Published var currentRoll: Double = 0
    @Published var measurementComplete: Bool = false
    @Published var slopeData: SlopeData? = nil
    
    @Published var stabilityProgress: Double = 0
    @Published var statusMessage: String = "Place phone face-down"
    
    @Published var waitingForPickup: Bool = false
    @Published var readyToAdvance: Bool = false
    
    // MARK: - Private Properties
    private let motionManager = CMMotionManager()
    private var stableStartTime: Date? = nil
    private let requiredStableSeconds: Double = 2.0
    private var isMonitoring = false
    private var flashDevice: AVCaptureDevice?
    
    private let faceDownThreshold: Double = 0.8
    private let stabilityThreshold: Double = 0.02
    
    init() {
        setupFlash()
    }
    
    private func setupFlash() {
        if let device = AVCaptureDevice.default(for: .video), device.hasTorch {
            flashDevice = device
        }
    }
    
    // MARK: - Start/Stop Monitoring
    func startMonitoring() {
        guard !isMonitoring else { return }
        guard motionManager.isDeviceMotionAvailable else {
            statusMessage = "Motion sensors not available"
            return
        }
        
        isMonitoring = true
        measurementComplete = false
        slopeData = nil
        stabilityProgress = 0
        stableStartTime = nil
        waitingForPickup = false
        readyToAdvance = false
        
        motionManager.deviceMotionUpdateInterval = 0.05
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            self.processMotion(motion)
        }
        
        statusMessage = "Place phone face-down"
    }
    
    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        isMonitoring = false
        stableStartTime = nil
        stabilityProgress = 0
    }
    
    // MARK: - Process Motion Data
    private func processMotion(_ motion: CMDeviceMotion) {
        let gravity = motion.gravity
        let acceleration = motion.userAcceleration
        
        // If waiting for pickup, check if phone is lifted
        if waitingForPickup {
            if gravity.z < 0.5 {
                statusMessage = "Moving to next..."
                waitingForPickup = false
                readyToAdvance = true
                stopMonitoring()
            }
            return
        }
        
        let wasFaceDown = isFaceDown
        isFaceDown = gravity.z > faceDownThreshold
        
        if isFaceDown {
            currentPitch = atan2(gravity.y, gravity.z) * 180 / .pi
            currentRoll = atan2(gravity.x, gravity.z) * 180 / .pi
            
            let totalAccel = sqrt(acceleration.x * acceleration.x +
                                  acceleration.y * acceleration.y +
                                  acceleration.z * acceleration.z)
            
            let currentlyStable = totalAccel < stabilityThreshold
            
            if currentlyStable {
                if stableStartTime == nil {
                    stableStartTime = Date()
                }
                
                let stableDuration = Date().timeIntervalSince(stableStartTime!)
                stabilityProgress = min(stableDuration / requiredStableSeconds, 1.0)
                
                if stableDuration >= requiredStableSeconds && !measurementComplete {
                    captureReading()
                }
                
                isStable = true
                statusMessage = "Hold steady..."
            } else {
                stableStartTime = nil
                stabilityProgress = 0
                isStable = false
                statusMessage = "Hold still..."
            }
        } else {
            stableStartTime = nil
            stabilityProgress = 0
            isStable = false
            
            if wasFaceDown {
                statusMessage = "Place phone face-down"
            }
        }
        
        isReadyToMeasure = isFaceDown && isStable
    }
    
    // MARK: - Capture Reading
    private func captureReading() {
        slopeData = SlopeData(pitch: currentPitch, roll: currentRoll)
        measurementComplete = true
        statusMessage = "Reading captured!"
        
        fireFlash()
        
        waitingForPickup = true
    }
    
    // MARK: - Flash Signal
    private func fireFlash() {
        guard let device = flashDevice, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            Task {
                for _ in 0..<2 {
                    device.torchMode = .on
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    device.torchMode = .off
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                device.unlockForConfiguration()
            }
        } catch {
            print("Flash error: \(error)")
        }
    }
    
    // MARK: - Reset
    func reset() {
        measurementComplete = false
        slopeData = nil
        stabilityProgress = 0
        stableStartTime = nil
        isFaceDown = false
        isStable = false
        waitingForPickup = false
        readyToAdvance = false
        statusMessage = "Place phone face-down"
    }
}
