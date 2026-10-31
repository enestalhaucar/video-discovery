/// What the player stage and the control bar show for a playback phase. Pure, so the mapping can be tested
/// without a player.
struct PlayerChrome: Equatable {
    let phase: PlayerModel.Phase
    /// True while the player wants to play but is waiting for data.
    let isBuffering: Bool

    // MARK: Stage

    var showsLoading: Bool { phase == .loading }
    var showsPlay: Bool { phase == .ready && !isBuffering }
    var showsBuffering: Bool { isBuffering && phase != .loading && phase != .failed }
    var showsReplay: Bool { phase == .ended }
    var showsFailure: Bool { phase == .failed }

    // MARK: Control bar

    /// Pause while playing, and while a play request is still waiting for data.
    var showsPause: Bool { phase == .playing || isBuffering }
    /// The bar is dimmed and disabled until the video has loaded.
    var dimsControls: Bool { phase == .loading }
}

extension PlayerChrome {
    @MainActor
    init(_ player: PlayerModel) {
        self.init(phase: player.phase, isBuffering: player.isBuffering)
    }
}
