import SwiftUI

/// Animation timings for the app's motion moments, kept in one place.
enum Motion {
    /// Skeleton highlight sweep, one loop.
    static let shimmerDuration = 1.2
    /// Skeleton or placeholder cross-fading into content.
    static let contentFade = Animation.easeOut(duration: 0.25)
    /// Newly revealed cards fade in and rise, one after another.
    static let reveal = Animation.easeOut(duration: 0.3)
    static let revealStagger = 0.06
    static let revealOffset: CGFloat = 12
    /// Card press and release.
    static let press = Animation.easeOut(duration: 0.12)
    static let release = Animation.spring(response: 0.3, dampingFraction: 0.7)
    /// Heart toggled on (pops to 1.3 with a burst) and off (dips to 0.85).
    static let heartPop = Spring(response: 0.35, dampingRatio: 0.5)
    static let heartDip = Spring(response: 0.3, dampingRatio: 0.7)
    static let heartBurstDuration = 0.3
    /// Overlays on the player stage.
    static let overlay = Animation.easeIn(duration: 0.18)
    /// Scrubber thumb growing while dragged.
    static let scrub = Animation.spring(response: 0.25, dampingFraction: 0.8)
    /// Skip arrow rotation and the "+10s" pill.
    static let skipRotation = Animation.easeInOut(duration: 0.125)
    static let skipPillDuration = 0.6
    /// Buffering spinner only shows when waiting lasts longer than this.
    static let bufferingDelay = 0.3
    /// Failure message fading in while rising.
    static let failure = Animation.easeOut(duration: 0.25)
    /// Search results and retry swaps.
    static let crossfade = Animation.easeInOut(duration: 0.2)
    /// Favourites inserted or removed.
    static let listChange = Animation.easeInOut(duration: 0.25)
    /// "You're all caught up" footer.
    static let endOfList = Animation.easeOut(duration: 0.4)
}
