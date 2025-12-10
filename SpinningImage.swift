import SwiftUI

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
    SpinningImage(imageName: "camera_button", duration: 2.0)
        .frame(width: 100, height: 100)
}
