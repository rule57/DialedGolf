import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Icon/Logo
            Image(systemName: "figure.golf")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Dialed Golf")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Perfect Your Putting")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 15) {
                InfoRow(icon: "ruler", text: "Measure distance to hole")
                InfoRow(icon: "level", text: "Analyze green slope at 3 points")
                InfoRow(icon: "target", text: "Get your perfect aimpoint")
            }
            .padding()
            .background(Color.white.opacity(0.8))
            .cornerRadius(15)
            .padding(.horizontal)
            
            Spacer()
            
            Button(action: onStart) {
                Text("Start Reading")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(15)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    WelcomeView(onStart: {})
}
