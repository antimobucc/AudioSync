import SwiftUI
import MultipeerConnectivity

struct HostView: View {
    var multipeer: MultipeerManager
    var audio: AudioSyncManager
    let onBack: () -> Void

    @State private var urlString: String = ""

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    topBar
                    devicesCard
                    songCard
                    if audio.isLoaded {
                        playerCard
                        volumeCard
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
        }
        .navigationBarHidden(true)
        .onAppear { multipeer.startHosting() }
        .onDisappear {
            multipeer.disconnect()
            audio.stop()
        }
        .alert(
            "Richiesta di connessione",
            isPresented: Binding(get: { multipeer.incomingPeer != nil }, set: { if !$0 { multipeer.declineInvitation() } })
        ) {
            Button("Accetta") { multipeer.acceptInvitation() }
            Button("Rifiuta", role: .cancel) { multipeer.declineInvitation() }
        } message: {
            if let peer = multipeer.incomingPeer {
                Text("\(peer.displayName) vuole unirsi alla sessione")
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Esci")
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            HStack(spacing: 8) {
                PulsingDot()
                Text("Host · \(multipeer.myPeerID.displayName)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("Esci")
            }
            .font(.subheadline)
            .foregroundStyle(.clear)
        }
        .padding(.top, 8)
    }

    private var devicesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Dispositivi", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(multipeer.connectedPeers.count + 1)")
                        .font(.title.bold())
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "A855F7"), Color(hex: "EC4899")], startPoint: .leading, endPoint: .trailing))
                }
                if multipeer.connectedPeers.count > 0 {
                    AmplificationBadge(deviceCount: multipeer.connectedPeers.count + 1)
                }
                Divider().background(Color.white.opacity(0.1))
                deviceRow(name: multipeer.myPeerID.displayName + " (tu)", isHost: true)
                if multipeer.connectedPeers.isEmpty {
                    Text("In attesa di dispositivi vicini…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                } else {
                    ForEach(multipeer.connectedPeers, id: \.displayName) { peer in
                        deviceRow(name: peer.displayName, isHost: false)
                    }
                }
            }
        }
    }

    private func deviceRow(name: String, isHost: Bool) -> some View {
        HStack(spacing: 10) {
            Circle().fill(isHost ? Color(hex: "A855F7") : .green).frame(width: 8, height: 8)
            Text(name).font(.subheadline).foregroundStyle(.white.opacity(0.8))
            Spacer()
            if isHost {
                Text("host").font(.caption2).foregroundStyle(Color(hex: "A855F7"))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(hex: "A855F7").opacity(0.15)).clipShape(Capsule())
            }
        }
    }

    private var songCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Canzone (URL Diretto MP3)", systemImage: "link")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                TextField("https://www.esempio.com/brano.mp3", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if audio.isBuffering {
                    HStack {
                        ProgressView().tint(Color(hex: "A855F7"))
                        Text("Buffering audio dal web...").font(.caption).foregroundStyle(.white.opacity(0.7))
                    }
                } else {
                    PrimaryButton(title: "Carica e Invia a Tutti", icon: "paperplane.fill", gradient: [Color(hex: "7B2FBE"), Color(hex: "C850C0")]) {
                        if let url = URL(string: urlString) {
                            audio.loadAudio(url: url)
                            multipeer.broadcastURL(url)
                            multipeer.broadcastClockSync()
                        }
                    }
                    .disabled(urlString.isEmpty)
                }
            }
        }
    }

    private var playerCard: some View {
        GlassCard {
            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(audio.currentFileName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(multipeer.connectedPeers.count + 1) speaker attivi")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    AudioBarsView(isPlaying: audio.isPlaying, color: Color(hex: "A855F7"))
                }
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { audio.currentTime },
                            set: { t in
                                audio.seek(to: t)
                                multipeer.sendCommand(SyncCommand(type: .seekTo, seekSeconds: t))
                            }
                        ),
                        in: 0...max(audio.duration, 1)
                    )
                    .tint(Color(hex: "A855F7"))
                    HStack {
                        Text(audio.formattedTime(audio.currentTime))
                        Spacer()
                        Text(audio.formattedTime(audio.duration))
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.4))
                }
                HStack(spacing: 0) {
                    Button("Stop", systemImage: "stop.fill") {
                        audio.stop()
                        multipeer.sendCommand(SyncCommand(type: .stop))
                    }.labelStyle(.iconOnly).font(.title3).foregroundStyle(.white.opacity(0.75)).frame(width: 36, height: 36)
                    Spacer()
                    Button("Rewind 10s", systemImage: "gobackward.10") {
                        let t = max(0, audio.currentTime - 10)
                        audio.seek(to: t)
                        multipeer.sendCommand(SyncCommand(type: .seekTo, seekSeconds: t))
                    }.labelStyle(.iconOnly).font(.title3).foregroundStyle(.white.opacity(0.75)).frame(width: 36, height: 36)
                    Spacer()
                    Button(audio.isPlaying ? "Pause" : "Play", systemImage: audio.isPlaying ? "pause.fill" : "play.fill", action: togglePlayPause)
                        .labelStyle(.iconOnly).font(.title2).foregroundStyle(.white).frame(width: 66, height: 66)
                        .background(Circle().fill(LinearGradient(colors: [Color(hex: "7B2FBE"), Color(hex: "C850C0")], startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: Color(hex: "7B2FBE").opacity(0.5), radius: 12))
                    Spacer()
                    Button("Forward 10s", systemImage: "goforward.10") {
                        let t = min(audio.duration, audio.currentTime + 10)
                        audio.seek(to: t)
                        multipeer.sendCommand(SyncCommand(type: .seekTo, seekSeconds: t))
                    }.labelStyle(.iconOnly).font(.title3).foregroundStyle(.white.opacity(0.75)).frame(width: 36, height: 36)
                    Spacer()
                    Button("Restart", systemImage: "backward.end.fill") {
                        audio.seek(to: 0)
                        multipeer.sendCommand(SyncCommand(type: .seekTo, seekSeconds: 0))
                    }.labelStyle(.iconOnly).font(.title3).foregroundStyle(.white.opacity(0.75)).frame(width: 36, height: 36)
                }.padding(.horizontal, 8)
            }
        }
    }

    private var volumeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "crown.fill").font(.caption).foregroundStyle(Color(hex: "F59E0B"))
                    Text("Controllo Volume").font(.subheadline.bold()).foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(audio.volume * 100))%").font(.title3.bold()).foregroundStyle(.white)
                }
                HStack(spacing: 14) {
                    Image(systemName: "speaker.fill").font(.caption).foregroundStyle(.white.opacity(0.35))
                    Slider(
                        value: Binding(get: { audio.volume }, set: { v in audio.setVolume(v); multipeer.sendCommand(SyncCommand(type: .setVolume, volume: v)) }),
                        in: 0...1
                    ).tint(Color(hex: "EC4899"))
                    Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundStyle(.white.opacity(0.35))
                }
            }
        }
    }

    private func togglePlayPause() {
            if audio.isPlaying {
                audio.pause()
                multipeer.sendCommand(SyncCommand(type: .pause))
            } else {
                // DYNAMIC DELAY:
                // If the song is already past 0 seconds, it's a "Resume". Give it a lightning-fast 0.15s delay.
                // If it's starting from the beginning, give it 1.2s to allow all phones to buffer from the web.
                let isResuming = audio.currentTime > 0
                let delay: Double = isResuming ? 0.15 : 1.2
                
                let scheduleAt = CACurrentMediaTime() + delay
                audio.play(scheduleAt: scheduleAt, clockOffset: 0)
                multipeer.sendCommand(SyncCommand(type: .play, hostTimestamp: CACurrentMediaTime(), scheduleAt: scheduleAt))
            }
        }
}
