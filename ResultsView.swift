import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingPhoneStandPrompt = false
    @State private var contentOpacity: Double = 0
    
    let onReset: () -> Void
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 40) {
                    // Header
                    Text("YOUR AIMPOINT")
                        .font(.custom("Potra", size: 14))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 60)
                    
                    // Aimpoint display
                    if let aimpoint = appState.currentReading.aimpoint {
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                                    .frame(width: 180, height: 180)
                                
                                Image(systemName: "location.north.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(aimpoint.direction))
                            }
                            
                            VStack(spacing: 4) {
                                Text(String(format: "%.1f°", abs(aimpoint.direction)))
                                    .font(.custom("AvenirNext-UltraLight", size: 48))
                                    .foregroundColor(.white)
                                
                                Text(aimDirectionText(aimpoint.direction))
                                    .font(.custom("AvenirNext-Medium", size: 16))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Text(aimpoint.breakSeverity.rawValue)
                                .font(.custom("AvenirNext-Medium", size: 14))
                                .foregroundColor(severityColor(aimpoint.breakSeverity))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(severityColor(aimpoint.breakSeverity).opacity(0.15))
                                .cornerRadius(20)
                        }
                    }
                    
                    // Summary
                    VStack(spacing: 16) {
                        if let distance = appState.currentReading.distance {
                            SummaryRow(label: "Distance", value: String(format: "%.1f ft", distance * 3.28084))
                        }
                        if let slope1 = appState.currentReading.slopeAt25Percent {
                            SummaryRow(label: "Slope at 1/3", value: String(format: "%.1f°", slope1.roll))
                        }
                        if let slope2 = appState.currentReading.slopeAt50Percent {
                            SummaryRow(label: "Slope at 2/3", value: String(format: "%.1f°", slope2.roll))
                        }
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        Button(action: { showingPhoneStandPrompt = true }) {
                            HStack {
                                Image(systemName: "iphone.gen3")
                                Text("Set up phone stand")
                            }
                            .font(.custom("AvenirNext-Medium", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        Button(action: onReset) {
                            Text("NEW READING")
                                .font(.custom("AvenirNext-DemiBold", size: 16))
                                .tracking(2)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .opacity(contentOpacity)
        }
        .sheet(isPresented: $showingPhoneStandPrompt) {
            PhoneStandPromptView()
        }
        .onAppear {
            calculateAimpoint()
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
            }
        }
    }
    
    private func aimDirectionText(_ direction: Double) -> String {
        if abs(direction) < 0.5 { return "Straight" }
        return direction > 0 ? "Aim Right" : "Aim Left"
    }
    
    private func severityColor(_ severity: BreakSeverity) -> Color {
        switch severity {
        case .minimal: return .green
        case .slight: return .blue
        case .moderate: return .orange
        case .severe: return .red
        case .extreme: return .purple
        }
    }
    
    private func calculateAimpoint() {
        guard let distance = appState.currentReading.distance,
              let slope1 = appState.currentReading.slopeAt25Percent,
              let slope2 = appState.currentReading.slopeAt50Percent else { return }
        
        let avgRoll = (slope1.roll + slope2.roll) / 2.0
        let avgMagnitude = (slope1.magnitude + slope2.magnitude) / 2.0
        let direction = -avgRoll * distance * 0.3
        
        let severity: BreakSeverity
        if avgMagnitude < 0.5 { severity = .minimal }
        else if avgMagnitude < 1.5 { severity = .slight }
        else if avgMagnitude < 3.0 { severity = .moderate }
        else if avgMagnitude < 5.0 { severity = .severe }
        else { severity = .extreme }
        
        appState.currentReading.aimpoint = Aimpoint(direction: direction, breakSeverity: severity)
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.custom("AvenirNext-Regular", size: 14))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.custom("AvenirNext-Medium", size: 14))
                .foregroundColor(.white)
        }
    }
}

struct PhoneStandPromptView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "iphone.gen3")
                    .font(.custom("AvenirNext-UltraLight", size: 80))
                    .foregroundColor(.white)
                
                Text("PHONE STAND")
                    .font(.custom("Potra", size: 14))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("GOT IT")
                        .font(.custom("AvenirNext-DemiBold", size: 16))
                        .tracking(2)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
    }
}

#Preview {
    ResultsView(onReset: {})
        .environmentObject(AppState())
}
