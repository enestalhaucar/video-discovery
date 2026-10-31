import SwiftUI
import Testing
import UIKit
@testable import VideoDiscovery

/// The player stage overlays and the control bar, drawn from `PlayerChrome` and plain values instead of a
/// playing video.
@MainActor
@Suite(.snapshotDevice, .serialized)
struct PlayerSnapshotTests {
    @Test(arguments: [
        ("loading", PlayerModel.Phase.loading),
        ("ready", .ready),
        ("ended", .ended),
        ("failed", .failed)
    ])
    func stageOverlay(name: String, phase: PlayerModel.Phase) async throws {
        let stage = Theme.stage
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay { PlayerStageLayers(chrome: PlayerChrome(phase: phase, isBuffering: false), skip: nil) }
        try await Snapshot.assert(stage, named: "stage-\(name)", layout: .fitting)
    }

    /// Before the video has loaded: dimmed, with unknown times.
    @Test func controlsWhileLoading() async throws {
        let player = PlayerModel(url: Video.samples[1].videoURL)
        let controls = PlaybackControls(player: player) { _ in }
        try await Snapshot.assert(controls, named: "controls-loading", layout: .fitting)
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func scrubberPartWayThrough(style: UIUserInterfaceStyle) async throws {
        let scrubber = Scrubber(
            currentTime: 3,
            duration: 10,
            dragTime: .constant(nil),
            onSeek: { _ in },
            onAdjust: { _ in }
        )
            .padding(.horizontal, Theme.Space.pt16)
            .background(Theme.background)
        try await Snapshot.assert(scrubber, named: "scrubber", style: style, layout: .fitting)
    }
}
