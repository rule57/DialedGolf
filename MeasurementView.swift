// MeasurementView.swift
// Combines distance measurement and slope instructions in one continuous AR experience

import SwiftUI
import ARKit

struct MeasurementView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var arService = ARDistanceService()
    @StateObject var slopeService = SlopeService()
    @State private var cursorCenter: CGPoint = .zero
    @State private var showingSlopeOverlay: Bool = false
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Layer 1: AR View (always visible)
            ARViewContainer(arService: arService, cursorCenter: $cursorCenter)
                .edgesIgnoringSafeArea(.all)
            
            // Layer 2: Cursor (only during distance measurement)
            if arService.currentPhase == .measuringDistance {
                GeometryReader { geometry in
                    if arService.showCursor && arService.pointsPlaced < 2 {
                        SpinningImage(imageName: "ar_cursor", duration: 3.0)
                            .frame(width: 200, height: 200)
                            .scaleEffect(arService.cursorScale)
                            .rotation3DEffect(
                                .degrees(arService.cursorPerspectiveTilt),
                                axis: (x: 1, y: 0, z: 0),
                                perspective: 0.5
                            )
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                }
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)
            }
            
            // Layer 3: UI based on current phase
            switch arService.currentPhase {
            case .measuringDistance:
                distanceMeasurementUI
                
            case .slopePrompt:
                slopePromptUI
                
            case .showingSlope1Instruction:
                slopeInstructionUI(slopeNumber: 1)
                
            case .waitingForSlope1:
                slopeMeasurementOverlay(slopeNumber: 1)
                
            case .showingSlope2Instruction:
                slopeInstructionUI(slopeNumber: 2)
                
            case .waitingForSlope2:
                slopeMeasurementOverlay(slopeNumber: 2)
                
            case .complete:
                Color.clear.onAppear {
                    onComplete()
                }
            }
        }
        .onDisappear {
            arService.stopSession()
            slopeService.stopMonitoring()
        }
        .onChange(of: slopeService.measurementComplete) { _, complete in
            if complete {
                handleSlopeComplete()
            }
        }
        .onChange(of: slopeService.readyToAdvance) { _, ready in
            if ready {
                handleSlopeAdvance()
            }
        }
    }
    
    // MARK: - Distance Measurement UI
    private var distanceMeasurementUI: some View {
        VStack(spacing: 0) {
            // Top status
            VStack(spacing: 8) {
                Text("MEASURE DISTANCE")
                    .font(.custom("Potra", size: 14))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.6))
                
                Text(distanceStatusText)
                    .font(.custom("AvenirNext-Regular", size: 16))
                    .foregroundColor(.white)
            }
            .padding(.top, 60)
            
            Spacer()
            
            // Distance display (after both points placed)
            if arService.pointsPlaced == 2, let distance = arService.measuredDistance {
                VStack(spacing: 8) {
                    Text(formatDistance(distance))
                        .font(.custom("AvenirNext-UltraLight", size: 56))
                        .foregroundColor(.white)
                    
                    Text("ball to hole")
                        .font(.custom("AvenirNext-Regular", size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 40)
            }
            
            Spacer()
            
            // Bottom controls
            HStack {
                // Left: Undo
                if arService.pointsPlaced > 0 && arService.pointsPlaced < 2 {
                    Button(action: { arService.reset() }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                } else {
                    Spacer().frame(width: 50)
                }
                
                Spacer()
                
                // Center: Main button
                if arService.pointsPlaced < 2 {
                    Button(action: { arService.placePoint() }) {
                        SpinningImage(imageName: "camera_button", duration: 2.0)
                            .frame(width: 140, height: 140)
                            .opacity(arService.canPlacePoint ? 1.0 : 0.3)
                    }
                    .disabled(!arService.canPlacePoint)
                } else {
                    // Confirm button - proceed to slope prompt
                    Button(action: {
                        if let distance = arService.measuredDistance {
                            appState.currentReading.distance = Double(distance)
                        }
                        arService.showSlopePrompt()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundColor(.black)
                        }
                    }
                }
                
                Spacer()
                
                // Right: Reset
                if arService.pointsPlaced == 2 {
                    Button(action: { arService.reset() }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                } else {
                    Spacer().frame(width: 50)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
            
            // Progress dots
            HStack(spacing: 8) {
                Circle()
                    .fill(arService.pointsPlaced >= 1 ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(arService.pointsPlaced >= 2 ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Slope Prompt UI
    private var slopePromptUI: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Semi-transparent prompt card at bottom
            VStack(spacing: 24) {
                Text("MEASURE SLOPE?")
                    .font(.custom("Potra", size: 18))
                    .foregroundColor(.white)
                
                Text("Get a more accurate aimpoint by measuring the green's slope")
                    .font(.custom("AvenirNext-Regular", size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 12) {
                    Button(action: {
                        arService.showSlope1Instruction()
                    }) {
                        Text("YES, MEASURE SLOPE")
                            .font(.custom("AvenirNext-DemiBold", size: 16))
                            .tracking(1)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(30)
                    }
                    
                    Button(action: {
                        arService.skipSlope()
                    }) {
                        Text("SKIP")
                            .font(.custom("AvenirNext-Medium", size: 16))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(30)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 20)
            .background(Color.black.opacity(0.85))
            .cornerRadius(20)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Slope Instruction UI (AR visible behind)
    private func slopeInstructionUI(slopeNumber: Int) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Semi-transparent instruction card at bottom
            VStack(spacing: 20) {
                Text("SLOPE \(slopeNumber) OF 2")
                    .font(.custom("Potra", size: 14))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.6))
                
                Text("Walk to the \(slopeNumber == 1 ? "1/3" : "2/3") marker")
                    .font(.custom("AvenirNext-Regular", size: 20))
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "figure.walk")
                        Text("Walk to the marker shown in AR")
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "iphone.gen3")
                        Text("Place phone face down on green")
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "hand.raised.slash")
                        Text("Hold still for 2 seconds")
                    }
                }
                .font(.custom("AvenirNext-Regular", size: 14))
                .foregroundColor(.white.opacity(0.7))
                
                Button(action: {
                    if slopeNumber == 1 {
                        arService.startSlope1Measurement()
                    } else {
                        arService.startSlope2Measurement()
                    }
                    slopeService.reset()
                    slopeService.startMonitoring()
                }) {
                    Text("START")
                        .font(.custom("AvenirNext-DemiBold", size: 16))
                        .tracking(2)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(30)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 20)
            .background(Color.black.opacity(0.85))
            .cornerRadius(20)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Slope Measurement Overlay
    private func slopeMeasurementOverlay(slopeNumber: Int) -> some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("SLOPE \(slopeNumber) OF 2")
                    .font(.custom("Potra", size: 14))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 60)
                
                Spacer()
                
                // Phone visualization
                ZStack {
                    Circle()
                        .fill(slopeStatusColor.opacity(0.15))
                        .frame(width: 200, height: 200)
                        .blur(radius: 30)
                    
                    Image(systemName: slopeService.measurementComplete ? "checkmark.circle" : "iphone.gen3")
                        .font(.system(size: 100, weight: .ultraLight))
                        .foregroundColor(slopeStatusColor)
                        .rotationEffect(.degrees(slopeService.isFaceDown ? 180 : 0))
                        .animation(.easeInOut(duration: 0.4), value: slopeService.isFaceDown)
                }
                
                Text(slopeService.statusMessage)
                    .font(.custom("AvenirNext-Regular", size: 18))
                    .foregroundColor(.white)
                
                // Progress ring
                if slopeService.isFaceDown && !slopeService.measurementComplete {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 4)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: slopeService.stabilityProgress)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(slopeService.stabilityProgress * 100))%")
                            .font(.custom("AvenirNext-Medium", size: 14))
                            .foregroundColor(.white)
                    }
                }
                
                // Results
                if slopeService.measurementComplete, let slope = slopeService.slopeData {
                    HStack(spacing: 40) {
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f°", slope.pitch))
                                .font(.custom("AvenirNext-UltraLight", size: 32))
                                .foregroundColor(.white)
                            Text("pitch")
                                .font(.custom("AvenirNext-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 1, height: 50)
                        
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f°", slope.roll))
                                .font(.custom("AvenirNext-UltraLight", size: 32))
                                .foregroundColor(.white)
                            Text("roll")
                                .font(.custom("AvenirNext-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
                
                // Pickup instruction
                if slopeService.waitingForPickup {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.raised")
                            .font(.system(size: 24))
                        Text("Pick up phone to continue")
                            .font(.custom("AvenirNext-Medium", size: 16))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 50)
                } else if !slopeService.measurementComplete {
                    Text("Place phone face down")
                        .font(.custom("AvenirNext-Regular", size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 50)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var distanceStatusText: String {
        if !arService.isPlaneDetected {
            return "Scanning surface..."
        }
        switch arService.pointsPlaced {
        case 0: return "Point at the ball"
        case 1: return "Point at the hole"
        default: return "Confirm distance"
        }
    }
    
    private var slopeStatusColor: Color {
        if slopeService.measurementComplete {
            return .green
        } else if slopeService.isFaceDown {
            return .orange
        }
        return .white
    }
    
    private func formatDistance(_ meters: Float) -> String {
        let feet = meters * 3.28084
        if feet >= 1 {
            return String(format: "%.1f ft", feet)
        } else {
            return String(format: "%.1f in", meters * 39.3701)
        }
    }
    
    private func handleSlopeComplete() {
        // Save slope data
        if let slope = slopeService.slopeData {
            switch arService.currentPhase {
            case .waitingForSlope1:
                appState.currentReading.slopeAt25Percent = slope
            case .waitingForSlope2:
                appState.currentReading.slopeAt50Percent = slope
            default:
                break
            }
        }
    }
    
    private func handleSlopeAdvance() {
        slopeService.stopMonitoring()
        
        switch arService.currentPhase {
        case .waitingForSlope1:
            arService.slope1Complete()
            slopeService.reset()
            arService.resumeSession()
        case .waitingForSlope2:
            arService.slope2Complete()
        default:
            break
        }
    }
}

#Preview {
    MeasurementView(onComplete: {})
        .environmentObject(AppState())
}
