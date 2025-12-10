import SwiftUI
import ARKit
import RealityKit
import Combine

// MARK: - AR Distance Service
class ARDistanceService: NSObject, ObservableObject {
    
    // MARK: - Published State
    @Published var pointsPlaced: Int = 0
    @Published var canPlacePoint: Bool = false
    @Published var measuredDistance: Float? = nil
    @Published var isPlaneDetected: Bool = false
    
    // Cursor properties
    @Published var cursorScale: CGFloat = 1.0
    @Published var showCursor: Bool = false
    @Published var cursorPerspectiveTilt: Double = 60
    
    // Flow state
    @Published var currentPhase: MeasurementPhase = .measuringDistance
    
    enum MeasurementPhase {
        case measuringDistance
        case slopePrompt           // NEW: Ask if user wants slope measurement
        case showingSlope1Instruction
        case waitingForSlope1
        case showingSlope2Instruction
        case waitingForSlope2
        case complete
    }
    
    // MARK: - Private Properties
    private var arView: ARView?
    private var startPosition: SIMD3<Float>?
    private var endPosition: SIMD3<Float>?
    private var lastHitResult: ARRaycastResult?
    
    // Anchors for markers
    private var ballMarkerAnchor: AnchorEntity?
    private var holeMarkerAnchor: AnchorEntity?
    private var oneThirdMarkerAnchor: AnchorEntity?
    private var twoThirdMarkerAnchor: AnchorEntity?
    private var dottedLineAnchors: [AnchorEntity] = []
    private var liveLineAnchors: [AnchorEntity] = []
    
    // Text label anchors
    private var instructionLabelAnchor: AnchorEntity?
    
    // Positions for slope measurements
    private(set) var oneThirdPosition: SIMD3<Float>?
    private(set) var twoThirdPosition: SIMD3<Float>?
    
    // MARK: - Session Control
    func startSession(with arView: ARView) {
        self.arView = arView
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)
        arView.session.delegate = self
    }
    
    func stopSession() {
        arView?.session.pause()
    }
    
    func pauseSession() {
        arView?.session.pause()
    }
    
    func resumeSession() {
        guard let arView = arView else { return }
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config, options: [])
    }
    
    // MARK: - Hit Test Update
    func updateHitTest(at screenPoint: CGPoint) {
        guard let arView = arView else {
            DispatchQueue.main.async {
                self.canPlacePoint = false
                self.showCursor = false
            }
            return
        }
        
        let actualCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        let results = arView.raycast(from: actualCenter, allowing: .estimatedPlane, alignment: .horizontal)
        
        if let result = results.first {
            self.lastHitResult = result
            
            let hitPosition = result.worldTransform.columns.3
            let position = SIMD3<Float>(hitPosition.x, hitPosition.y, hitPosition.z)
            let cameraPosition = arView.cameraTransform.translation
            let distance = simd_distance(position, cameraPosition)
            
            let cameraToHit = position - cameraPosition
            let horizontalDistance = sqrt(cameraToHit.x * cameraToHit.x + cameraToHit.z * cameraToHit.z)
            let verticalDistance = abs(cameraToHit.y)
            let lookDownAngle = atan2(verticalDistance, horizontalDistance) * 180 / .pi
            
            DispatchQueue.main.async {
                self.isPlaneDetected = true
                self.canPlacePoint = true
                self.showCursor = true
                
                let scale = 0.7 / max(distance, 0.3)
                self.cursorScale = CGFloat(min(max(scale, 0.5), 1.3))
                self.cursorPerspectiveTilt = Double(90 - lookDownAngle)
            }
            
            // Update live dashed line from ball to cursor if ball is placed
            if pointsPlaced == 1, let start = startPosition {
                updateLiveDashedLine(from: start, to: position)
            }
        } else {
            DispatchQueue.main.async {
                self.canPlacePoint = false
                self.showCursor = false
            }
            self.lastHitResult = nil
        }
    }
    
    // MARK: - Place Point
    func placePoint() {
        guard let result = lastHitResult else { return }
        
        let hitPosition = result.worldTransform.columns.3
        let position = SIMD3<Float>(hitPosition.x, hitPosition.y, hitPosition.z)
        
        if pointsPlaced == 0 {
            // Place ball marker
            startPosition = position
            placeBallishMarker(at: position, anchorType: .ball)
            pointsPlaced = 1
            
        } else if pointsPlaced == 1 {
            guard let start = startPosition else { return }
            endPosition = position
            
            // Place hole marker
            placeBallishMarker(at: position, anchorType: .hole)
            
            // Clear live line and draw final dashed line
            clearLiveLine()
            drawDashedLine(from: start, to: position)
            
            // Calculate and place 1/3 and 2/3 markers
            oneThirdPosition = start + (position - start) * (1.0/3.0)
            twoThirdPosition = start + (position - start) * (2.0/3.0)
            
            placeBallishMarker(at: oneThirdPosition!, anchorType: .oneThird)
            placeBallishMarker(at: twoThirdPosition!, anchorType: .twoThird)
            
            measuredDistance = simd_distance(start, position)
            pointsPlaced = 2
        }
    }
    
    // MARK: - Slope Instruction Flow
    func showSlope1Instruction() {
        currentPhase = .showingSlope1Instruction
        if let pos = oneThirdPosition {
            showInstructionLabel(at: pos, text: "1/3")
        }
    }
    
    func showSlopePrompt() {
        currentPhase = .slopePrompt
    }
    
    func skipSlope() {
        currentPhase = .complete
    }
    
    func startSlope1Measurement() {
        currentPhase = .waitingForSlope1
        removeInstructionLabel()
    }
    
    func slope1Complete() {
        currentPhase = .showingSlope2Instruction
        if let pos = twoThirdPosition {
            showInstructionLabel(at: pos, text: "2/3")
        }
    }
    
    func startSlope2Measurement() {
        currentPhase = .waitingForSlope2
        removeInstructionLabel()
    }
    
    func slope2Complete() {
        currentPhase = .complete
        removeInstructionLabel()
    }
    
    // MARK: - Instruction Label
    private func showInstructionLabel(at position: SIMD3<Float>, text: String) {
        guard let arView = arView else { return }
        
        removeInstructionLabel()
        
        // Create text mesh
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.06, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        
        var material = UnlitMaterial()
        material.color = .init(tint: .white)
        
        let textEntity = ModelEntity(mesh: textMesh, materials: [material])
        
        // Center the text
        let bounds = textEntity.visualBounds(relativeTo: nil)
        textEntity.position.x = -bounds.center.x
        textEntity.position.z = -bounds.center.z
        
        // Create anchor above the marker position
        let labelPosition = position + SIMD3<Float>(0, 0.12, 0)
        let anchor = AnchorEntity(world: labelPosition)
        anchor.addChild(textEntity)
        
        arView.scene.addAnchor(anchor)
        instructionLabelAnchor = anchor
    }
    
    private func removeInstructionLabel() {
        instructionLabelAnchor?.removeFromParent()
        instructionLabelAnchor = nil
    }
    
    // MARK: - Reset
    func reset() {
        startPosition = nil
        endPosition = nil
        measuredDistance = nil
        pointsPlaced = 0
        lastHitResult = nil
        currentPhase = .measuringDistance
        oneThirdPosition = nil
        twoThirdPosition = nil
        
        // Remove all markers
        ballMarkerAnchor?.removeFromParent()
        holeMarkerAnchor?.removeFromParent()
        oneThirdMarkerAnchor?.removeFromParent()
        twoThirdMarkerAnchor?.removeFromParent()
        ballMarkerAnchor = nil
        holeMarkerAnchor = nil
        oneThirdMarkerAnchor = nil
        twoThirdMarkerAnchor = nil
        
        // Remove lines
        for anchor in dottedLineAnchors {
            anchor.removeFromParent()
        }
        dottedLineAnchors.removeAll()
        
        clearLiveLine()
        removeInstructionLabel()
    }
    
    // MARK: - Marker Types
    enum MarkerType {
        case ball
        case hole
        case oneThird
        case twoThird
    }
    
    // MARK: - Place Ballish Marker
    private func placeBallishMarker(at position: SIMD3<Float>, anchorType: MarkerType) {
        guard let arView = arView else { return }
        
        // Much bigger sizes
        let size: Float = anchorType == .ball || anchorType == .hole ? 0.15 : 0.10
        let mesh = MeshResource.generatePlane(width: size, height: size)
        
        var material = UnlitMaterial()
        
        // Load texture
        if let uiImage = UIImage(named: "ballish"),
           let cgImage = uiImage.cgImage {
            do {
                let texture = try TextureResource.generate(from: cgImage, options: .init(semantic: .color))
                material.color = .init(tint: .white, texture: .init(texture))
                material.blending = .transparent(opacity: 1.0)
            } catch {
                print("Failed to create texture: \(error)")
                material.color = .init(tint: .white)
            }
        } else {
            print("Could not load ballish image - using fallback")
            material.color = .init(tint: .white)
        }
        
        let marker = ModelEntity(mesh: mesh, materials: [material])
        marker.transform.rotation = simd_quatf(angle: -.pi/2, axis: [1, 0, 0])
        
        let anchor = AnchorEntity(world: position + SIMD3<Float>(0, 0.005, 0))
        anchor.addChild(marker)
        arView.scene.addAnchor(anchor)
        
        switch anchorType {
        case .ball:
            ballMarkerAnchor?.removeFromParent()
            ballMarkerAnchor = anchor
        case .hole:
            holeMarkerAnchor?.removeFromParent()
            holeMarkerAnchor = anchor
        case .oneThird:
            oneThirdMarkerAnchor?.removeFromParent()
            oneThirdMarkerAnchor = anchor
        case .twoThird:
            twoThirdMarkerAnchor?.removeFromParent()
            twoThirdMarkerAnchor = anchor
        }
    }
    
    // MARK: - Live Dashed Line
    private func updateLiveDashedLine(from start: SIMD3<Float>, to end: SIMD3<Float>) {
        clearLiveLine()
        
        guard let arView = arView else { return }
        
        let distance = simd_distance(start, end)
        let dashLength: Float = 0.03
        let gapLength: Float = 0.025
        let segmentLength = dashLength + gapLength
        let dashCount = Int(distance / segmentLength)
        
        guard dashCount > 0 else { return }
        
        let direction = normalize(end - start)
        
        for i in 0..<dashCount {
            let dashStart = Float(i) * segmentLength
            let dashCenter = dashStart + (dashLength / 2)
            let dashPosition = start + direction * dashCenter
            
            let mesh = MeshResource.generateBox(size: [0.006, 0.003, dashLength])
            var material = UnlitMaterial()
            material.color = .init(tint: .white.withAlphaComponent(0.7))
            
            let dash = ModelEntity(mesh: mesh, materials: [material])
            
            let rotationMatrix = createRotationMatrix(direction: direction)
            dash.transform.rotation = simd_quatf(rotationMatrix)
            
            let anchor = AnchorEntity(world: dashPosition + SIMD3<Float>(0, 0.002, 0))
            anchor.addChild(dash)
            arView.scene.addAnchor(anchor)
            liveLineAnchors.append(anchor)
        }
    }
    
    private func clearLiveLine() {
        for anchor in liveLineAnchors {
            anchor.removeFromParent()
        }
        liveLineAnchors.removeAll()
    }
    
    // MARK: - Final Dashed Line
    private func drawDashedLine(from start: SIMD3<Float>, to end: SIMD3<Float>) {
        guard let arView = arView else { return }
        
        for anchor in dottedLineAnchors {
            anchor.removeFromParent()
        }
        dottedLineAnchors.removeAll()
        
        let distance = simd_distance(start, end)
        let dashLength: Float = 0.03
        let gapLength: Float = 0.025
        let segmentLength = dashLength + gapLength
        let dashCount = Int(distance / segmentLength)
        
        guard dashCount > 0 else { return }
        
        let direction = normalize(end - start)
        
        for i in 0...dashCount {
            let dashStart = Float(i) * segmentLength
            let dashCenter = dashStart + (dashLength / 2)
            
            if dashCenter > distance { break }
            
            let dashPosition = start + direction * dashCenter
            
            let mesh = MeshResource.generateBox(size: [0.008, 0.003, dashLength])
            var material = UnlitMaterial()
            material.color = .init(tint: .white)
            
            let dash = ModelEntity(mesh: mesh, materials: [material])
            
            let rotationMatrix = createRotationMatrix(direction: direction)
            dash.transform.rotation = simd_quatf(rotationMatrix)
            
            let anchor = AnchorEntity(world: dashPosition + SIMD3<Float>(0, 0.002, 0))
            anchor.addChild(dash)
            arView.scene.addAnchor(anchor)
            dottedLineAnchors.append(anchor)
        }
    }
    
    private func createRotationMatrix(direction: SIMD3<Float>) -> simd_float3x3 {
        let up = SIMD3<Float>(0, 1, 0)
        var right = cross(up, direction)
        if simd_length(right) < 0.001 {
            right = SIMD3<Float>(1, 0, 0)
        }
        right = normalize(right)
        let correctedUp = normalize(cross(direction, right))
        return simd_float3x3(columns: (right, correctedUp, direction))
    }
}

// MARK: - ARSessionDelegate
extension ARDistanceService: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if anchor is ARPlaneAnchor {
                DispatchQueue.main.async {
                    self.isPlaneDetected = true
                }
            }
        }
    }
}
