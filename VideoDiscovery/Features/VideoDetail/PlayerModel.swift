import AVFoundation
import Combine
import Observation
import OSLog

/// Playback state for one video on the detail screen.
///
/// The view calls `activate()` when it appears and `deactivate()` when it disappears. Observers only live
/// between those two calls, and every callback is delivered on the main queue.
@MainActor
@Observable
final class PlayerModel {
    enum Phase: Equatable {
        case loading, ready, playing, paused, ended, failed
    }

    let player: AVPlayer
    private(set) var phase: Phase = .loading
    /// True while the player wants to play but is waiting for data.
    private(set) var isBuffering = false
    /// Seconds, always finite and >= 0.
    private(set) var currentTime: Double = 0
    /// Seconds, 0 until the item knows its length.
    private(set) var duration: Double = 0

    nonisolated private static let logger = Logger(subsystem: "com.enestalhaucar.VideoDiscovery", category: "Player")

    private let url: URL
    @ObservationIgnored private var item: AVPlayerItem?
    @ObservationIgnored private var observers: Set<AnyCancellable> = []
    @ObservationIgnored private var timeObserver: Any?
    // Time ticks are ignored while a seek is in flight, so the reported time doesn't jump back.
    @ObservationIgnored private var seekID = 0
    @ObservationIgnored private var isSeeking = false

    init(url: URL) {
        self.url = url
        player = AVPlayer()
    }

    deinit {
        Self.logger.debug("PlayerModel released")
    }

    // MARK: - Lifecycle

    /// Builds the item on the first call, then (re)attaches the observers and catches up with the player.
    func activate() {
        attach(item ?? AVPlayerItem(url: url))
    }

    /// Pauses and drops the observers. The item, position and phase stay for the next `activate()`.
    func deactivate() {
        pause()
        removeObservers()
    }

    // MARK: - Commands

    func play() {
        guard phase != .failed, item != nil else { return }
        if phase == .ended {
            seek(to: 0)
        }
        player.play()
    }

    /// Leaves `.ended` and `.failed` alone, so both survive a tab switch.
    func pause() {
        guard phase != .failed, phase != .ended else { return }
        player.pause()
        isBuffering = false
        if phase == .playing {
            phase = .paused
        }
    }

    func togglePlayback() {
        // The player's own status also covers a play request that is still buffering, so a second tap cancels it.
        if player.timeControlStatus == .paused {
            play()
        } else {
            pause()
        }
    }

    func seek(to seconds: Double) {
        guard phase != .failed, !seconds.isNaN else { return }
        let target = min(max(seconds, 0), duration)
        currentTime = target
        if phase == .ended, target < duration {
            phase = .paused
        }
        // An item that isn't ready yet has nothing to seek: it starts at 0.
        guard item?.status == .readyToPlay else { return }

        seekID += 1
        let id = seekID
        isSeeking = true
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] _ in
            Task { @MainActor in self?.seekDidFinish(id) }
        }
    }

    func skip(by seconds: Double) {
        seek(to: currentTime + seconds)
    }

    func replay() {
        seek(to: 0)
        play()
    }

    /// Starts over with a new item after a failure.
    func retry() {
        guard phase == .failed else { return }
        phase = .loading
        attach(AVPlayerItem(url: url))
    }

    // MARK: - Observation

    /// The only place that binds the player to an item, so observers never stay on an old one.
    private func attach(_ newItem: AVPlayerItem) {
        removeObservers()
        if player.currentItem !== newItem {
            player.replaceCurrentItem(with: newItem)
        }
        item = newItem
        observe(newItem)

        // Catch up with whatever changed while nothing was observing.
        handleStatus(newItem.status, of: newItem)
        handleTimeControlStatus(player.timeControlStatus)
        syncTimes()
    }

    private func observe(_ item: AVPlayerItem) {
        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                MainActor.assumeIsolated { self?.handleStatus(status, of: item) }
            }
            .store(in: &observers)

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                MainActor.assumeIsolated { self?.handleTimeControlStatus(status) }
            }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.handleEnd(of: item) }
            }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                MainActor.assumeIsolated { self?.handleFailure(error, of: item) }
            }
            .store(in: &observers)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func removeObservers() {
        observers.removeAll()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
    }

    // MARK: - Callbacks

    private func handleStatus(_ status: AVPlayerItem.Status, of item: AVPlayerItem) {
        guard item === self.item else { return }
        switch status {
        case .readyToPlay:
            syncTimes()
            if phase == .loading {
                phase = .ready
            }
        case .failed:
            handleFailure(item.error, of: item)
        default:
            break
        }
    }

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        guard phase != .failed else { return }
        isBuffering = status == .waitingToPlayAtSpecifiedRate
        switch status {
        case .playing:
            phase = .playing
        case .paused where phase == .playing:
            phase = .paused
        default:
            break
        }
    }

    private func handleEnd(of item: AVPlayerItem) {
        guard item === self.item, phase != .failed else { return }
        isBuffering = false
        currentTime = duration
        phase = .ended
    }

    private func handleFailure(_ error: (any Error)?, of item: AVPlayerItem) {
        guard item === self.item, phase != .failed else { return }
        Self.logger.error("Playback failed: \(error.map { String(describing: $0) } ?? "unknown error")")
        player.pause()
        isBuffering = false
        phase = .failed
    }

    private func tick() {
        guard !isSeeking else { return }
        syncTimes()
    }

    private func seekDidFinish(_ id: Int) {
        guard id == seekID else { return }
        isSeeking = false
        syncTimes()
    }

    // MARK: - Time

    private func syncTimes() {
        guard let item else { return }
        let newDuration = Self.seconds(item.duration)
        if newDuration != duration {
            duration = newDuration
        }
        let time = Self.seconds(player.currentTime())
        currentTime = duration > 0 ? min(time, duration) : time
    }

    /// `CMTime` can be indefinite or invalid (always for an item that fails), which reads as NaN.
    private static func seconds(_ time: CMTime) -> Double {
        let value = time.seconds
        return value.isFinite ? max(value, 0) : 0
    }
}
