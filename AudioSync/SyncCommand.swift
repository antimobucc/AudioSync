import Foundation

struct SyncCommand: Codable, Sendable {
    enum CommandType: String, Codable, Sendable {
        case play
        case pause
        case stop
        case setVolume
        case seekTo
        case syncClock
        case loadURL
    }

    var type: CommandType
    var hostTimestamp: Double?
    var scheduleAt: Double?
    var volume: Float?
    var seekSeconds: Double?
    var audioURL: String?
}
