//
//  VideoInstructionView.swift
//  DialedGolf
//
//  Created by William Rule on 12/9/25.
//

import SwiftUI
import AVKit

struct VideoInstructionView: View {
    @State var videoFinished = false
    @Environment(\.dismiss) private var dismiss
    
    let onReady: () -> Void
    
    private var player: AVPlayer = {
        guard let url = Bundle.main.url(forResource: "its_ready", withExtension: "mp4") else {
            fatalError("its_ready.mp4 not found in bundle")
        }
        return AVPlayer(url: url)
    }()
    
    var body: some View {
        ZStack {
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .onAppear {
                    setupEndObserver()
                    player.seek(to: .zero)
                    player.play()
                }
            
            if videoFinished {
                VStack {
                    Spacer()
                    Button(action: {
                        onReady()
                    }) {
                        Text("Ready")
                            .font(.system(size: 24, weight: .bold))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Capsule())
                            .shadow(radius: 6)
                    }
                    .padding(.bottom, 40)
                    .transition(.opacity.animation(.easeIn(duration: 0.4)))
                }
            }
        }
    }
    
    /// When video ends → show button
    private func setupEndObserver() {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                               object: player.currentItem,
                                               queue: .main) { _ in
            withAnimation {
                videoFinished = true
            }
        }
    }
}
