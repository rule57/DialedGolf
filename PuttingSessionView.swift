// PuttingSessionView.swift
// Ball detection → Putter Yes/No → Loop with stats

import SwiftUI
import AVFoundation
import Vision

struct PuttingSessionView: View {
    let onRestart: () -> Void
    
    @StateObject private var cameraService = BallDetectionService()
    @State private var puttsMade: Int = 0
    @State private var puttsAttempted: Int = 0
    @State private var sessionState: SessionState = .waitingForBall
    @State private var putterCountdown: Double = 6.0
    @State private var countdownTimer: Timer?
    @State private var showHitIndicator: Bool = false
    
    enum SessionState {
        case waitingForBall      // Watching for ball to be hit
        case ballHit             // Ball was hit, brief transition
        case waitingForPutter    // Waiting for putter yes/no (6 sec)
        case resultShown         // Showing result briefly
    }
    
    var body: some View {
        ZStack {
            // Camera feed
            CameraPreviewView(cameraService: cameraService)
                .ignoresSafeArea()
            
            // Rotate everything 180° for upside-down phone orientation
            VStack {
                // Stats display (top, but upside down so appears at bottom when phone flipped)
                HStack {
                    // Restart button (bottom-left when phone is flipped)
                    Button(action: onRestart) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()

                    // Stats
                    StatsView(made: puttsMade, attempted: puttsAttempted)
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                // Detection status chips
                HStack(spacing: 10) {
                    BallPresenceChip(state: cameraService.ballPresenceState)

                    HitStatusChip(isVisible: showHitIndicator)
                }
                .padding(.top, 10)
                
                Spacer()
                
                // Status indicator
                VStack(spacing: 15) {
                    switch sessionState {
                    case .waitingForBall:
                        PulsingCircle(color: .white)
                        Text("Waiting for putt...")
                            .font(.custom("AvenirNext-Medium", size: 16))
                            .foregroundColor(.white)
                        
                        // Debug info
                        VStack(spacing: 4) {
                            Text("Baseline: \(cameraService.isBaselineReady ? "Ready" : "Setting...")")
                                .font(.custom("AvenirNext-Regular", size: 12))
                            Text("Motion: \(String(format: "%.4f", cameraService.debugMotionValue))")
                                .font(.custom("AvenirNext-Regular", size: 12))
                            Text("Threshold: 0.15")
                                .font(.custom("AvenirNext-Regular", size: 12))
                        }
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 10)
                        
                    case .ballHit:
                        Image(systemName: "checkmark.circle.fill")
                            .font(.custom("AvenirNext-UltraLight", size: 50))
                            .foregroundColor(.green)
                        Text("Ball hit!")
                            .font(.custom("AvenirNext-Medium", size: 16))
                            .foregroundColor(.white)
                        
                    case .waitingForPutter:
                        VStack(spacing: 10) {
                            Text("Did it go in?")
                                .font(.custom("Potra", size: 22))
                                .foregroundColor(.white)
                            
                            Text("Show putter face")
                                .font(.custom("AvenirNext-Regular", size: 14))
                                .foregroundColor(.white.opacity(0.7))
                            
                            // Countdown ring
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 4)
                                    .frame(width: 60, height: 60)
                                
                                Circle()
                                    .trim(from: 0, to: putterCountdown / 6.0)
                                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .frame(width: 60, height: 60)
                                    .rotationEffect(.degrees(-90))
                                
                                Text("\(Int(putterCountdown))")
                                    .font(.custom("AvenirNext-Bold", size: 18))
                                    .foregroundColor(.white)
                            }
                        }
                        
                    case .resultShown:
                        EmptyView()
                    }
                }
                .padding(.bottom, 100)
            }
            .rotationEffect(.degrees(180)) // Flip for upside-down phone
            
            // Result overlay
            if sessionState == .resultShown {
                ResultFlashView(made: puttsMade > 0 && puttsAttempted > 0)
                    .rotationEffect(.degrees(180))
            }
        }
        .onAppear {
            cameraService.startSession()
            cameraService.onBallHit = handleBallHit
            cameraService.onPutterResult = handlePutterResult
        }
        .onDisappear {
            cameraService.stopSession()
            countdownTimer?.invalidate()
        }
    }
    
    private func handleBallHit() {
        sessionState = .ballHit
        puttsAttempted += 1
        showHitIndicator = true

        // Brief delay then wait for putter
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            sessionState = .waitingForPutter
            putterCountdown = 6.0
            startPutterCountdown()
            cameraService.startPutterDetection()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showHitIndicator = false
        }
    }
    
    private func startPutterCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            putterCountdown -= 0.1
            if putterCountdown <= 0 {
                timer.invalidate()
                // Timeout - count as miss
                handlePutterResult(made: false)
            }
        }
    }
    
    private func handlePutterResult(made: Bool) {
        countdownTimer?.invalidate()
        cameraService.stopPutterDetection()
        
        if made {
            puttsMade += 1
        }
        
        sessionState = .resultShown
        
        // Show result briefly then reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            sessionState = .waitingForBall
            cameraService.resetBallDetection()
        }
    }
}

// MARK: - Stats View
struct StatsView: View {
    let made: Int
    let attempted: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(made)")
                .font(.custom("AvenirNext-Bold", size: 32))
                .foregroundColor(.green)
            
            Text("/")
                .font(.custom("AvenirNext-Regular", size: 24))
                .foregroundColor(.white.opacity(0.5))
            
            Text("\(attempted)")
                .font(.custom("AvenirNext-Bold", size: 32))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6))
        .cornerRadius(20)
    }
}

// MARK: - Ball Status Chips
struct BallPresenceChip: View {
    let state: BallDetectionService.BallPresenceState

    var body: some View {
        let text: String
        let color: Color

        switch state {
        case .locked:
            text = "Ball locked"
            color = .green
        case .searching:
            text = "Looking for ball"
            color = .orange
        }

        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(text)
                .font(.custom("AvenirNext-Medium", size: 13))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.55))
        .clipShape(Capsule())
    }
}

struct HitStatusChip: View {
    let isVisible: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 10, height: 10)

            Text("Hit detected")
                .font(.custom("AvenirNext-Medium", size: 13))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.35))
        .clipShape(Capsule())
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
    }
}

// MARK: - Pulsing Circle (waiting indicator)
struct PulsingCircle: View {
    let color: Color
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(color.opacity(0.3))
            .frame(width: 80, height: 80)
            .overlay(
                Circle()
                    .fill(color)
                    .frame(width: 20, height: 20)
            )
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Result Flash View
struct ResultFlashView: View {
    let made: Bool
    
    var body: some View {
        ZStack {
            Color(made ? .green : .red)
                .opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 10) {
                Image(systemName: made ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.custom("AvenirNext-UltraLight", size: 80))
                    .foregroundColor(made ? .green : .red)
                
                Text(made ? "MADE" : "MISS")
                    .font(.custom("AvenirNext-Bold", size: 24))
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    PuttingSessionView(onRestart: {})
}
