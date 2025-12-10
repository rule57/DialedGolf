import Foundation
import Combine

/// Central state manager for the app
class AppState: ObservableObject {
    @Published var currentReading: PuttingReading = PuttingReading()
    @Published var readingHistory: [PuttingReading] = []
    
    private let userDefaultsKey = "DialedGolf_ReadingHistory"
    
    init() {
        loadHistory()
    }
    
    /// Save the current reading and add it to history
    func saveCurrentReading() {
        guard currentReading.isComplete else { return }
        
        readingHistory.append(currentReading)
        saveHistory()
        
        // Reset for next reading
        currentReading = PuttingReading()
    }
    
    /// Clear the current reading
    func resetCurrentReading() {
        currentReading = PuttingReading()
    }
    
    // MARK: - Persistence
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(readingHistory) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([PuttingReading].self, from: data) {
            readingHistory = decoded
        }
    }
}
