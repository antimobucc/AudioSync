import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
class AudioSyncManager: NSObject {

    var isPlaying: Bool = false
    var currentTime: Double = 0
    var duration: Double = 0
    var volume: Float = 1.0
    var currentFileName: String = ""
    var isLoaded: Bool = false
    var isBuffering: Bool = false

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?

    override init() {
        super.init()
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("[AudioSync] Errore AVAudioSession: \(error)")
        }
    }

    func loadAudio(url: URL) {
        stop()
        isLoaded = false
        isBuffering = true
        currentFileName = url.lastPathComponent
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
        player?.volume = volume

        // Observe when the stream is fully buffered and ready to play
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                if item.status == .readyToPlay {
                    self?.isBuffering = false
                    self?.isLoaded = true
                    let durationSeconds = item.duration.seconds
                    self?.duration = durationSeconds.isNaN ? 0 : durationSeconds
                } else if item.status == .failed {
                    self?.isBuffering = false
                    print("Errore nel caricamento del link.")
                }
            }
        }
        
        setupTimeObserver()
    }

    private func setupTimeObserver() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, let player = self.player else { return }
            self.currentTime = time.seconds.isNaN ? 0 : time.seconds
            self.isPlaying = player.rate != 0
        }
    }

    func play(scheduleAt hostScheduleTime: Double, clockOffset: Double = 0) {
        guard let player = player else { return }
        
        let localNow = CACurrentMediaTime()
        let localScheduleTime = hostScheduleTime + clockOffset
        let delay = localScheduleTime - localNow

        if delay > 0.01 {
            // Aspetta il momento esatto per far partire lo streaming
            Task {
                try? await Task.sleep(for: .seconds(delay))
                player.play()
            }
        } else {
            // Se siamo in ritardo, calcoliamo quanto e facciamo un seek
            let overdue = -delay
            if overdue < duration {
                player.seek(to: CMTime(seconds: overdue, preferredTimescale: 600))
            }
            player.play()
        }
    }

    func pause() {
            player?.pause()
            // Tells the hardware to stay warmed up and ready for an instant resume
            player?.preroll(atRate: 1.0) { _ in }
        }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        currentTime = 0
    }

    func seek(to seconds: Double) {
        let clamped = max(0, min(seconds, duration))
        player?.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
    }

    func setVolume(_ vol: Float) {
        volume = max(0, min(vol, 1))
        player?.volume = volume
    }

    func handleCommand(_ cmd: SyncCommand, clockOffset: Double) {
        switch cmd.type {
        case .loadURL:
            if let urlString = cmd.audioURL, let url = URL(string: urlString) {
                loadAudio(url: url)
            }
        case .play:
            if let scheduleAt = cmd.scheduleAt {
                play(scheduleAt: scheduleAt, clockOffset: clockOffset)
            } else {
                player?.play()
            }
        case .pause: pause()
        case .stop: stop()
        case .setVolume: if let v = cmd.volume { setVolume(v) }
        case .seekTo: if let s = cmd.seekSeconds { seek(to: s) }
        case .syncClock: break
        }
    }

    func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        return Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}
