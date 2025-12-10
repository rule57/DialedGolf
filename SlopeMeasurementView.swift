import SwiftUI

struct SlopeMeasurementView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var slopeService = SlopeService()
    
    let intervalFraction: String  // "1/3" or "2/3"
    let intervalIndex: Int        // 1 or 2
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top status
                VStack(spacing: 8) {
                    Text("CHECK SLOPE")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\(intervalFraction) to hole")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Main visual
                VStack(spacing: 30) {
                    // Phone illustration
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(statusColor.opacity(0.15))
                            .frame(width: 200, height: 200)
                            .blur(radius: 30)
                        
                        // Phone icon
                        Image(systemName: phoneIcon)
                            .font(.system(size: 100, weight: .ultraLight))
                            .foregroundColor(statusColor)
                            .rotationEffect(.degrees(slopeService.isFaceDown ? 180 : 0))
                            .animation(.easeInOut(duration: 0.4), value: slopeService.isFaceDown)
                    }
                    
                    // Status message
                    Text(slopeService.statusMessage)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    // Progress ring (when stabilizing)
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
                                .animation(.linear(duration: 0.1), value: slopeService.stabilityProgress)
                            
                            Text("\(Int(slopeService.stabilityProgress * 100))%")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Slope data (when complete)
                    if slopeService.measurementComplete, let slope = slopeService.slopeData {
                        HStack(spacing: 40) {
                            VStack(spacing: 4) {
                                Text(String(format: "%.1f°", slope.pitch))
                                    .font(.system(size: 32, weight: .light, design: .rounded))
                                    .foregroundColor(.white)
                                Text("pitch")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 1, height: 50)
                            
                            VStack(spacing: 4) {
                                Text(String(format: "%.1f°", slope.roll))
                                    .font(.system(size: 32, weight: .light, design: .rounded))
                                    .foregroundColor(.white)
                                Text("roll")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.top, 20)
                    }
                }
                
                Spacer()
                
                // Bottom instruction
                if !slopeService.measurementComplete {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "iphone.gen3")
                                .font(.system(size: 14))
                            Text("Place phone face down")
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 14))
                        
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.slash")
                                .font(.system(size: 14))
                            Text("Hold still for 2 seconds")
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 14))
                    }
                    .padding(.bottom, 50)
                } else if slopeService.waitingForPickup {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.raised")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Pick up to continue")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 50)
                } else {
                    Spacer().frame(height: 80)
                }
                
                // Progress dots
                HStack(spacing: 8) {
                    Circle()
                        .fill(intervalIndex >= 1 ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(intervalIndex >= 2 ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            slopeService.startMonitoring()
        }
        .onDisappear {
            slopeService.stopMonitoring()
        }
        .onChange(of: slopeService.readyToAdvance) { _, isReady in
            if isReady {
                saveSlopeData()
                onComplete()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        if slopeService.measurementComplete {
            return .green
        } else if slopeService.isFaceDown {
            return .orange
        } else {
            return .white
        }
    }
    
    private var phoneIcon: String {
        if slopeService.measurementComplete {
            return "checkmark.circle"
        } else {
            return "iphone.gen3"
        }
    }
    
    // MARK: - Save Data
    
    private func saveSlopeData() {
        guard let slope = slopeService.slopeData else { return }
        
        switch intervalIndex {
        case 1:
            appState.currentReading.slopeAt25Percent = slope
        case 2:
            appState.currentReading.slopeAt50Percent = slope
        default:
            break
        }
    }
}

#Preview {
    SlopeMeasurementView(intervalFraction: "1/3", intervalIndex: 1, onComplete: {})
        .environmentObject(AppState())
}
