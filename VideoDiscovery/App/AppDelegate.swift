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
    /// Allows `mask` and rotates the window to `orientation` straight away.
    static func set(_ mask: UIInterfaceOrientationMask, rotatingTo orientation: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = mask
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation)) { _ in }
        }
    }
}
