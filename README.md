# Dialed Golf - Setup Instructions

## Phase 1: Basic UI (Current Version)

This is the initial setup with the complete UI flow and placeholder functionality.

### Setup Steps:

1. **Create New Xcode Project:**
   - Open Xcode
   - File → New → Project
   - Choose: iOS → App
   - Product Name: `DialedGolf`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Click Next and save

2. **Add Files to Your Project:**
   - Download all the Swift files from the outputs folder
   - In Xcode, right-click on your project folder
   - Choose "Add Files to DialedGolf..."
   - Select all the downloaded Swift files
   - Make sure "Copy items if needed" is checked
   - Click Add

3. **Update Info.plist:**
   - In Xcode, find Info.plist in your project
   - Add these entries (or merge with the provided Info.plist):
     - NSCameraUsageDescription: "Dialed Golf needs camera access to measure distance on the putting green using AR."
     - NSMotionUsageDescription: "Dialed Golf needs motion sensor access to measure the slope of the putting green."

4. **Build and Run:**
   - Select a simulator or your iPhone
   - Click the Play button (or Cmd+R)
   - The app should launch!

### Current Features:
✅ Complete UI flow from welcome to results
✅ Step-by-step navigation
✅ Data models and state management
✅ Simulated measurements (for testing)
✅ Results calculation and display
✅ Data persistence

### What Works Now:
- You can click through the entire flow
- Simulated distance measurement (3.5m)
- Simulated slope measurements at all 3 points
- Aimpoint calculation based on slope data
- Phone stand prompt

### Next Steps (Phase 2):
- Integrate ARKit for real distance measurement
- Integrate Core Motion for real slope detection
- Add phone orientation detection (face-down check)
- Fine-tune aimpoint algorithm

### File Structure:
```
DialedGolf/
├── DialedGolfApp.swift          # App entry point
├── Models/
│   ├── PuttingReading.swift     # Data structures
│   └── AppState.swift           # State management
└── Views/
    ├── ContentView.swift        # Main navigation
    ├── WelcomeView.swift        # Welcome screen
    ├── DistanceMeasurementView.swift  # AR distance
    ├── SlopeMeasurementView.swift     # Slope reading
    └── ResultsView.swift        # Results & aimpoint
```

### Testing:
1. Run the app
2. Click "Start Reading"
3. Click "Simulate Measurement" for distance
4. For each slope reading:
   - Click "Simulate Face Down"
   - Click "Measure Slope"
   - Click "Continue"
5. View your results!

### Notes:
- This version uses simulated data so you can test the UI flow
- Real sensor integration coming in Phase 2
- All data is saved using UserDefaults
- The app requires iOS 17+ for best SwiftUI support

Ready to test! Let me know if you encounter any issues or want to add Phase 2 features.
