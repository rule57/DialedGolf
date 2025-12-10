// DistanceMeasurementView.swift

import SwiftUI
import ARKit

struct DistanceMeasurementView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var arService = ARDistanceService()
    @State private var cursorCenter: CGPoint = .zero
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Layer 1: AR View (full screen)
            ARViewContainer(arService: arService, cursorCenter: $cursorCenter)
                .edgesIgnoringSafeArea(.all)
            
            // Layer 2: Cursor at screen center
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
            
            // Layer 3: Clean black UI overlay
            VStack(spacing: 0) {
                // Top status area
                VStack(spacing: 8) {
                    // Step indicator
                    Text("MEASURE DISTANCE")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.6))
                    
                    // Status text
                    Text(statusText)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Distance display (after both points placed)
                if arService.pointsPlaced == 2, let distance = arService.measuredDistance {
                    VStack(spacing: 8) {
                        Text(formatDistance(distance))
                            .font(.system(size: 56, weight: .light, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("ball to hole")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.bottom, 40)
                }
                
                Spacer()
                
                // Bottom controls
                HStack {
                    // Left: Undo button
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
                        // Continue button
                        Button(action: {
                            if let distance = arService.measuredDistance {
                                appState.currentReading.distance = Double(distance)
                            }
                            arService.stopSession()
                            onComplete()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Right: Reset button (when complete)
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
                
                // Point indicator dots
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
        .onDisappear {
            arService.stopSession()
        }
    }
    
    private var statusText: String {
        if !arService.isPlaneDetected {
            return "Scanning surface..."
        }
        switch arService.pointsPlaced {
        case 0: return "Point at the ball"
        case 1: return "Point at the hole"
        default: return "Distance measured"
        }
    }
    
    private func formatDistance(_ meters: Float) -> String {
        let feet = meters * 3.28084
        if feet >= 1 {
            return String(format: "%.1f ft", feet)
        } else {
            let inches = meters * 39.3701
            return String(format: "%.1f in", inches)
        }
    }
}

// MARK: - Spinning Image Component
struct SpinningImage: View {
    let imageName: String
    let duration: Double
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let rotation = (seconds.truncatingRemainder(dividingBy: duration)) / duration * 360
            
            Image(imageName)
                .resizable()
                .scaledToFit()
                .rotationEffect(.degrees(rotation))
        }
    }
}

#Preview {
    DistanceMeasurementView(onComplete: {})
        .environmentObject(AppState())
}
