import MultipeerConnectivity
import Foundation
import Observation

typealias MCInvitationHandler = @Sendable (Bool, MCSession?) -> Void

@Observable
@MainActor
class MultipeerManager: NSObject {
    static let serviceType = "audiosync-v1"

    var connectedPeers: [MCPeerID] = []
    var isHost: Bool = false
    var incomingPeer: MCPeerID? = nil

    @ObservationIgnored var onCommandReceived: ((SyncCommand) -> Void)?

    let myPeerID: MCPeerID
    private(set) var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var pendingInvitationHandler: MCInvitationHandler?

    private(set) var clockOffset: Double = 0
    private var clockSamples: [Double] = []

    override init() {
        myPeerID = MCPeerID(displayName: UIDevice.current.name)
        super.init()
        resetSession()
    }

    private func resetSession() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    func startHosting() {
        isHost = true
        resetSession()
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["role": "host"], serviceType: Self.serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func acceptInvitation() {
        pendingInvitationHandler?(true, session)
        pendingInvitationHandler = nil
        incomingPeer = nil
    }

    func declineInvitation() {
        pendingInvitationHandler?(false, nil)
        pendingInvitationHandler = nil
        incomingPeer = nil
    }

    func startBrowsing() {
        isHost = false
        resetSession()
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func disconnect() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
        advertiser = nil
        browser = nil
        
        connectedPeers = []
        isHost = false
        incomingPeer = nil
        clockOffset = 0
        clockSamples = []
    }

    func sendCommand(_ command: SyncCommand) {
        guard isHost, !session.connectedPeers.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(command)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("[Multipeer] Errore invio comando: \(error)")
        }
    }

    func broadcastClockSync() {
        guard isHost else { return }
        sendCommand(SyncCommand(type: .syncClock, hostTimestamp: CACurrentMediaTime()))
    }
    
    func broadcastURL(_ url: URL) {
        guard isHost else { return }
        sendCommand(SyncCommand(type: .loadURL, audioURL: url.absoluteString))
    }

    private func updateClockOffset(hostTime: Double, receivedAt: Double) {
        let sample = hostTime - receivedAt
        clockSamples.append(sample)
        if clockSamples.count > 10 { clockSamples.removeFirst() }
        clockOffset = clockSamples.reduce(0, +) / Double(clockSamples.count)
    }
}

extension MultipeerManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.connectedPeers = session.connectedPeers
            if self.isHost && state == .connected {
                try? await Task.sleep(for: .seconds(0.5))
                self.broadcastClockSync()
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let receiveTime = CACurrentMediaTime()
        Task { @MainActor in
            guard let cmd = try? JSONDecoder().decode(SyncCommand.self, from: data) else { return }
            if cmd.type == .syncClock, let ht = cmd.hostTimestamp {
                self.updateClockOffset(hostTime: ht, receivedAt: receiveTime)
                return
            }
            self.onCommandReceived?(cmd)
        }
    }

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
}

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping MCInvitationHandler) {
        Task { @MainActor in
            self.incomingPeer = peerID
            self.pendingInvitationHandler = invitationHandler
        }
    }
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
}

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 15)
        }
    }
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
