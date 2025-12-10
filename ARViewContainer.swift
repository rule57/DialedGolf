//
//  ARViewContainer.swift
//  DialedGolf
//
//  Created by William Rule on 12/9/25.
//

// FILE 2 of 3: ARViewContainer.swift
// Copy everything below this line and paste into a new Swift file named "ARViewContainer.swift"
import SwiftUI
import ARKit
import RealityKit

/// Simple SwiftUI wrapper for ARView - no gestures, no cursor tracking
struct ARViewContainer: UIViewRepresentable {
    var arService: ARDistanceService
    @Binding var cursorCenter: CGPoint
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arService.startSession(with: arView)
        
        // Set up a timer to check hit testing
        context.coordinator.startHitTestTimer()
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update cursor position for hit testing
        context.coordinator.cursorCenter = cursorCenter
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(arService: arService)
    }
    
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.stopHitTestTimer()
        uiView.session.pause()
    }
    
    class Coordinator: NSObject {
        var arService: ARDistanceService
        var hitTestTimer: Timer?
        var cursorCenter: CGPoint = .zero
        
        init(arService: ARDistanceService) {
            self.arService = arService
        }
        
        func startHitTestTimer() {
            hitTestTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.arService.updateHitTest(at: self.cursorCenter)
            }
        }
        
        func stopHitTestTimer() {
            hitTestTimer?.invalidate()
            hitTestTimer = nil
        }
    }
}
