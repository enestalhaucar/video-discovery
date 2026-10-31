import Testing
@testable import VideoDiscovery

struct PlayerChromeTests {
    /// What one phase should show: the stage overlay first, then the control bar.
    struct Expectation: CustomTestStringConvertible, Sendable {
        let phase: PlayerModel.Phase
        let isBuffering: Bool
        var loading = false
        var play = false
        var buffering = false
        var replay = false
        var failure = false
        var pause = false
        var dimmed = false

        var testDescription: String { "\(phase)\(isBuffering ? " + buffering" : "")" }
    }

    static let expectations: [Expectation] = [
        Expectation(phase: .loading, isBuffering: false, loading: true, dimmed: true),
        // Autoplay asks before the item is ready: still only the loading spinner, but Pause is offered.
        Expectation(phase: .loading, isBuffering: true, loading: true, pause: true, dimmed: true),
        Expectation(phase: .ready, isBuffering: false, play: true),
        // A play request waiting for data hides the big play button and shows the buffering spinner.
        Expectation(phase: .ready, isBuffering: true, buffering: true, pause: true),
        Expectation(phase: .playing, isBuffering: false, pause: true),
        Expectation(phase: .playing, isBuffering: true, buffering: true, pause: true),
        Expectation(phase: .paused, isBuffering: false),
        // A seek while paused can wait for data too.
        Expectation(phase: .paused, isBuffering: true, buffering: true, pause: true),
        Expectation(phase: .ended, isBuffering: false, replay: true),
        // Replay tapped: until the player reports playing, Replay stays and the delayed spinner may join it.
        Expectation(phase: .ended, isBuffering: true, buffering: true, replay: true, pause: true),
        Expectation(phase: .failed, isBuffering: false, failure: true)
    ]

    @Test(arguments: expectations)
    func phaseMapsToWhatIsShown(_ expected: Expectation) {
        let chrome = PlayerChrome(phase: expected.phase, isBuffering: expected.isBuffering)

        #expect(chrome.showsLoading == expected.loading)
        #expect(chrome.showsPlay == expected.play)
        #expect(chrome.showsBuffering == expected.buffering)
        #expect(chrome.showsReplay == expected.replay)
        #expect(chrome.showsFailure == expected.failure)
        #expect(chrome.showsPause == expected.pause)
        #expect(chrome.dimsControls == expected.dimmed)
    }
}

struct PlaybackClockTests {
    @Test(arguments: [
        (0.0, "0:00"),
        (0.4, "0:00"),
        (0.5, "0:01"),
        (9.6, "0:10"),
        (59.4, "0:59"),
        (59.5, "1:00"),
        (61, "1:01"),
        (600, "10:00"),
        (3_725, "62:05"),
        (-3, "0:00")
    ])
    func formatsSecondsAsMinutesAndSeconds(_ seconds: Double, _ text: String) {
        #expect(PlaybackClock.text(seconds) == text)
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity])
    func unknownLengthsReadAsDashes(_ seconds: Double) {
        #expect(PlaybackClock.text(seconds) == "--:--")
        #expect(PlaybackClock.unknown == "--:--")
    }
}
