import UIKit

/// Keeps the app in portrait, except while a video plays full screen.
final class AppDelegate: NSObject, UIApplicationDelegate {
    @MainActor static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.orientationLock
    }
}

@MainActor
enum OrientationLock {
    /// Allows `mask` without forcing a rotation: the screen follows the device when the user turns it,
    /// with the system's own rotation animation.
    static func allow(_ mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = mask
        for scene in windowScenes {
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    /// Allows only `mask` and animates the window into it straight away.
    static func force(_ mask: UIInterfaceOrientationMask) {
        allow(mask)
        for scene in windowScenes {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        }
    }

    private static var windowScenes: [UIWindowScene] {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    }
}
