import SwiftUI

struct ContentView: View {
    @State private var multipeer = MultipeerManager()
    @State private var audio = AudioSyncManager()
    @State private var role: AppRole? = nil

    enum AppRole { case host, client }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if let role = role {
                    if role == .host {
                        HostView(multipeer: multipeer, audio: audio) {
                            self.role = nil
                        }
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    } else {
                        ClientView(multipeer: multipeer, audio: audio) {
                            self.role = nil
                        }
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    }
                } else {
                    RoleSelectionView { selected in
                        withAnimation(.spring(response: 0.4)) {
                            role = selected
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
