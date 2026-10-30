import SwiftUI

enum AppTab: Hashable {
    case discover
    case favorites
}

extension EnvironmentValues {
    /// Whether the tab that hosts a view is the selected one.
    ///
    /// `onDisappear` is not a reliable signal for tab switches, so screens that must react to them
    /// (the video player pauses) read this value instead.
    @Entry var isTabActive = true
}
