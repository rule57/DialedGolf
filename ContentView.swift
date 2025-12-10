import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep: AppStep = .welcome
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            switch currentStep {
            case .welcome:
                WelcomeView(onStart: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .measurement
                    }
                })
                
            case .measurement:
                MeasurementView(onComplete: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .tutorial
                    }
                })
                
            case .tutorial:
                TutorialVideoView(onReady: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .putting
                    }
                })
                
            case .putting:
                PuttingSessionView(onRestart: {
                    appState.resetCurrentReading()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .welcome
                    }
                })
                
            case .results:
                ResultsView(onReset: {
                    appState.saveCurrentReading()
                    appState.resetCurrentReading()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .welcome
                    }
                })
            }
        }
    }
}

enum AppStep {
    case welcome
    case measurement  // Combined distance + slope
    case tutorial     // Video tutorial
    case putting      // Ball detection + yes/no loop
    case results      // (optional - could show after exiting putting)
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
