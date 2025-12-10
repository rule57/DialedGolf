import Foundation

/// Stores all the measurement data for a putting green reading
struct PuttingReading: Codable {
    var distance: Double?              // Distance in meters from ball to hole
    var slopeAt25Percent: SlopeData?   // Slope at 1/4 distance
    var slopeAt50Percent: SlopeData?   // Slope at 1/2 distance
    var slopeAt75Percent: SlopeData?   // Slope at 3/4 distance
    var aimpoint: Aimpoint?            // Calculated aimpoint
    var timestamp: Date = Date()
    
    var isComplete: Bool {
        distance != nil &&
        slopeAt25Percent != nil &&
        slopeAt50Percent != nil &&
        slopeAt75Percent != nil &&
        aimpoint != nil
    }
}

/// Represents slope data at a specific point
struct SlopeData: Codable {
    var pitch: Double      // Forward/backward tilt (degrees)
    var roll: Double       // Left/right tilt (degrees)
    var timestamp: Date = Date()
    
    /// Combined slope magnitude
    var magnitude: Double {
        sqrt(pitch * pitch + roll * roll)
    }
}

/// Represents the calculated aimpoint for the putt
struct Aimpoint: Codable {
    var direction: Double  // Direction to aim (degrees from straight)
    var breakSeverity: BreakSeverity
    var timestamp: Date = Date()
}

enum BreakSeverity: String, Codable {
    case minimal = "Minimal Break"
    case slight = "Slight Break"
    case moderate = "Moderate Break"
    case severe = "Severe Break"
    case extreme = "Extreme Break"
}
