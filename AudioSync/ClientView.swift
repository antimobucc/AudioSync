import SwiftUI

struct ClientView: View {
    var multipeer: MultipeerManager
    var audio: AudioSyncManager
    let onBack: () -> Void

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 16) {
                topBar
                statusCard

                if audio.isBuffering {
                    bufferingCard
                } else if audio.isLoaded {
                    nowPlayingCard
                } else if multipeer.connectedPeers.isEmpty {
                    waitingCard
                } else {
                    waitingForFileCard
                }

                Spacer()
                lockNote
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .navigationBarHidden(true)
        .onAppear {
            multipeer.startBrowsing()
            multipeer.onCommandReceived = { [weak multipeer, weak audio] cmd in
                guard let audio = audio, let mp = multipeer else { return }
                audio.handleCommand(cmd, clockOffset: mp.clockOffset)
            }
        }
        .onDisappear {
            multipeer.disconnect()
            audio.stop()
        }
    }

    private var bufferingCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "00B4D8")))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Buffering audio dal web...")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text(audio.currentFileName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
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
            Text("Dispositivo")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
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

    private var statusCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(statusColor.opacity(0.15)).frame(width: 46, height: 46)
                    Image(systemName: statusIcon).font(.title3).foregroundStyle(statusColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle).font(.subheadline.bold()).foregroundStyle(.white)
                    Text(statusSubtitle).font(.caption).foregroundStyle(.white.opacity(0.45)).lineLimit(2)
                }
                Spacer()
                if isConnected { PulsingDot(color: .green) }
            }
        }
    }

    private var waitingCard: some View {
        GlassCard {
            VStack(spacing: 20) {
                ZStack {
                    ForEach(0..<3) { i in RippleCircle(delay: Double(i) * 0.5) }
                    Image(systemName: "wifi").font(.title).foregroundStyle(.white.opacity(0.7))
                }.frame(height: 100)
                Text("Ricerca di una sessione in corso…").font(.subheadline).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                Text("Assicurati che l'host abbia aperto l'app\ne che siate sulla stessa rete WiFi").font(.caption).foregroundStyle(.white.opacity(0.35)).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity).padding(.vertical, 12)
        }
    }

    private var waitingForFileCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "00B4D8")))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Connesso · in attesa del link")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text("L'host invierà a breve il link audio")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }

    private var nowPlayingCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("In riproduzione", systemImage: "music.note").font(.caption.bold()).foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    AudioBarsView(isPlaying: audio.isPlaying, color: Color(hex: "00B4D8"))
                }
                Text(audio.currentFileName).font(.headline).foregroundStyle(.white).lineLimit(2)
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1)).frame(height: 5)
                            Capsule()
                                .fill(LinearGradient(colors: [Color(hex: "0077B6"), Color(hex: "00B4D8")], startPoint: .leading, endPoint: .trailing))
                                .frame(width: audio.duration > 0 ? geo.size.width * CGFloat(audio.currentTime / audio.duration) : 0, height: 5)
                        }
                    }.frame(height: 5)
                    HStack {
                        Text(audio.formattedTime(audio.currentTime))
                        Spacer()
                        Text(audio.formattedTime(audio.duration))
                    }.font(.caption2.monospacedDigit()).foregroundStyle(.white.opacity(0.35))
                }
            }
        }
    }

    private var lockNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill").font(.caption2)
            Text("Solo l'host controlla riproduzione e volume").font(.caption2)
        }.foregroundStyle(.white.opacity(0.2)).padding(.bottom, 24)
    }

    private var isConnected: Bool { !multipeer.connectedPeers.isEmpty }
    private var statusColor: Color { isConnected ? .green : Color(hex: "F59E0B") }
    private var statusIcon: String { isConnected ? "checkmark.circle.fill" : "magnifyingglass" }
    private var statusTitle: String { isConnected ? "Connesso alla sessione" : "Ricerca sessione…" }
    private var statusSubtitle: String { isConnected ? "Pronto — l'audio partirà automaticamente" : "Stai cercando host vicini via WiFi / Bluetooth" }
}
struct RippleCircle: View {
    let delay: Double
    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(Color(hex: "00B4D8").opacity(animate ? 0 : 0.4), lineWidth: 1.5)
            .frame(width: animate ? 100 : 30, height: animate ? 100 : 30)
            .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false).delay(delay), value: animate)
            .onAppear { animate = true }
    }
}
