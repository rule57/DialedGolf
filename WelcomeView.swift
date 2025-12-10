import SwiftUI
import AVKit

struct WelcomeView: View {
    let onStart: () -> Void
    @State private var logoOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background video
            BackgroundVideoPlayer(videoName: "welcome_bg")
                .ignoresSafeArea()
            
            // Dark overlay for readability
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: -15) {
                    Text("DIALED")
                        .font(.custom("Potra", size: 90))
                        .foregroundColor(.white)
                    
                    Text("GOLF")
                        .font(.custom("AvenirNext-Regular", size: 30))
                        .tracking(12)
                        .foregroundColor(.white.opacity(0.6))
                }
                .opacity(logoOpacity)
                
                Spacer()
                
                VStack(spacing: 20) {
                    FeatureRow(icon: "ruler", text: "Measure distance")
                    FeatureRow(icon: "level", text: "Analyze slope")
                    FeatureRow(icon: "target", text: "Get your aimpoint")
                }
                .opacity(logoOpacity)
                .padding(.horizontal, 40)
                
                Spacer()
                
                Button(action: onStart) {
                    Text("START")
                        .font(.custom("AvenirNext-Regular", size: 25))
                        .tracking(4)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .cornerRadius(20)
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 60)
                .opacity(buttonOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                logoOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                buttonOpacity = 1
            }
        }
    }
}

// MARK: - Background Video Player
struct BackgroundVideoPlayer: UIViewRepresentable {
    let videoName: String
    
    func makeUIView(context: Context) -> UIView {
        let view = VideoBackgroundView(videoName: videoName)
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Force layout update
        uiView.setNeedsLayout()
    }
}

class VideoBackgroundView: UIView {
    private var player: AVQueuePlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerLooper: AVPlayerLooper?
    
    init(videoName: String) {
        super.init(frame: UIScreen.main.bounds)
        setupVideo(named: videoName)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupVideo(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") ??
                        Bundle.main.url(forResource: name, withExtension: "mov") else {
            print("Background video '\(name)' not found")
            backgroundColor = .black
            return
        }
        
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        player = AVQueuePlayer(playerItem: item)
        player?.isMuted = true
        
        // Loop the video
        if let player = player {
            playerLooper = AVPlayerLooper(player: player, templateItem: item)
        }
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = UIScreen.main.bounds
        
        if let playerLayer = playerLayer {
            layer.addSublayer(playerLayer)
        }
        
        player?.play()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)
            
            Text(text)
                .font(.custom("AvenirNext-Regular", size: 16))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
    }
}

#Preview {
    WelcomeView(onStart: {})
}
