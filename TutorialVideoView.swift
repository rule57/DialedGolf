// TutorialVideoView.swift
// Plays tutorial video, freezes on last frame, shows READY button

import SwiftUI
import AVKit

struct TutorialVideoView: View {
    let onReady: () -> Void
    
    @State private var player: AVPlayer?
    @State private var videoEnded = false
    @State private var lastFrameImage: UIImage?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if videoEnded, let image = lastFrameImage {
                // Show frozen last frame
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } else if let player = player {
                // Show video
                VideoPlayerView(player: player)
                    .ignoresSafeArea()
            }
            
            // READY button (appears when video ends)
            if videoEnded {
                VStack {
                    Spacer()
                    Spacer()
                    Spacer()
                    
                    Button(action: onReady) {
                        Text("READY")
                            .font(.custom("Potra", size: 24))
                            .tracking(4)
                            .foregroundColor(.black)
                            .frame(width: 200, height: 60)
                            .background(Color.white)
                            .cornerRadius(30)
                    }
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func setupPlayer() {
        // Look for tutorial video in bundle
        guard let url = Bundle.main.url(forResource: "tutorial", withExtension: "mp4") ??
                        Bundle.main.url(forResource: "tutorial", withExtension: "mov") else {
            print("Tutorial video not found in bundle")
            // Skip to ready if no video
            videoEnded = true
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: playerItem)
        self.player = avPlayer
        
        // Listen for video end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            captureLastFrame()
            videoEnded = true
        }
        
        avPlayer.play()
    }
    
    private func captureLastFrame() {
        guard let player = player,
              let currentItem = player.currentItem else { return }
        
        let asset = currentItem.asset
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        let duration = currentItem.duration
        let time = CMTimeSubtract(duration, CMTime(value: 1, timescale: 30)) // 1 frame before end
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            lastFrameImage = UIImage(cgImage: cgImage)
        } catch {
            print("Failed to capture last frame: \(error)")
        }
    }
}

// MARK: - Video Player UIViewRepresentable
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

class PlayerUIView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

#Preview {
    TutorialVideoView(onReady: {})
}
