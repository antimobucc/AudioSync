//
//  AppBackground.swift
//  AudioSync
//
//  Created by Antimo Bucciero on 30/03/2026.
//


import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(hex: "080812").ignoresSafeArea()
            RadialGradient(colors: [Color(hex: "3D1A6E").opacity(0.5), .clear], center: .init(x: 0.2, y: 0.1), startRadius: 0, endRadius: 350).ignoresSafeArea()
            RadialGradient(colors: [Color(hex: "0D4E6E").opacity(0.35), .clear], center: .init(x: 0.85, y: 0.85), startRadius: 0, endRadius: 300).ignoresSafeArea()
        }
    }
}

struct RoleSelectionView: View {
    let onSelect: (ContentView.AppRole) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: "7B2FBE"), Color(hex: "C850C0")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 90, height: 90)
                        .shadow(color: Color(hex: "7B2FBE").opacity(0.6), radius: 20)
                    Image(systemName: "hifispeaker.2.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(.white)
                }
                Text("AudioSync")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Più dispositivi · volume amplificato")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            VStack(spacing: 14) {
                RoleCard(role: .host, title: "Crea Sessione", subtitle: "Scegli la musica e controlla la riproduzione", icon: "crown.fill", colors: [Color(hex: "7B2FBE"), Color(hex: "C850C0")], onSelect: onSelect)
                RoleCard(role: .client, title: "Unisciti", subtitle: "Connettiti alla sessione di un host vicino", icon: "link.circle.fill", colors: [Color(hex: "0077B6"), Color(hex: "00B4D8")], onSelect: onSelect)
            }
            .padding(.horizontal, 22)
            Spacer().frame(height: 50)
            Text("Connessione locale via WiFi / Bluetooth — nessun internet richiesto")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.25))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer().frame(height: 30)
        }
    }
}

struct RoleCard: View {
    let role: ContentView.AppRole
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    let onSelect: (ContentView.AppRole) -> Void
    @State private var pressed = false

    var body: some View {
        Button { onSelect(role) } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 54, height: 54)
                        .shadow(color: colors.first!.opacity(0.5), radius: 10)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .scaleEffect(pressed ? 0.97 : 1)
        .animation(.spring(response: 0.25), value: pressed)
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in pressed = true }.onEnded { _ in pressed = false })
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial.opacity(0.6))
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.09), lineWidth: 1))
    }
}

struct PulsingDot: View {
    var color: Color = .green
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.25)).frame(width: pulse ? 22 : 12, height: pulse ? 22 : 12).animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
            Circle().fill(color).frame(width: 10, height: 10)
        }
        .onAppear { pulse = true }
    }
}

struct AudioBarsView: View {
    var isPlaying: Bool
    var color: Color = .green
    var barCount: Int = 5
    @State private var heights: [CGFloat] = []

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: isPlaying ? heights[safe: i] ?? 8 : 4)
                    .animation(isPlaying ? .easeInOut(duration: Double.random(in: 0.25...0.45)).repeatForever(autoreverses: true).delay(Double(i) * 0.07) : .easeOut(duration: 0.2), value: isPlaying)
            }
        }
        .onAppear { heights = (0..<barCount).map { _ in CGFloat.random(in: 8...20) } }
        .onChange(of: isPlaying) { _, play in if play { heights = (0..<barCount).map { _ in CGFloat.random(in: 8...20) } } }
    }
}

extension Array { subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil } }

struct AmplificationBadge: View {
    let deviceCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path")
                .font(.caption)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(deviceCount) dispositivi attivi · +\( (10 * log10(Double(deviceCount))).formatted(.number.precision(.fractionLength(1))) ) dB")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                Text("Amplificazione percepita stimata")
                    .font(.caption2)
                    .foregroundStyle(.green.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.3), lineWidth: 1))
    }
}

struct PrimaryButton: View {
    let title: String
    let icon: String
    let gradient: [Color]
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.85) } else { Image(systemName: icon) }
                Text(title).fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Group { if isDisabled || isLoading { Color.white.opacity(0.08) } else { LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing) } })
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isDisabled || isLoading)
        .scaleEffect(pressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2), value: pressed)
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in pressed = true }.onEnded { _ in pressed = false })
    }
}