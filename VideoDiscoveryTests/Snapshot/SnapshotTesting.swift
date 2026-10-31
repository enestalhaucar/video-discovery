import SwiftUI
import Testing
import UIKit

/// A tiny snapshot helper: renders a SwiftUI view in a window the size of an iPhone 17 and compares it with a
/// reference PNG in `VideoDiscoveryTests/__Snapshots__`. A missing reference is recorded and the test fails once,
/// so it has to be looked at and run again.
enum Snapshot {
    /// The simulator the references were recorded on. Rendering differs between models and OS versions.
    static let referenceModel = "iPhone18,3"
    static let referenceModelName = "iPhone 17"
    static let referenceOS = (major: 27, minor: 0)

    /// iPhone 17 in portrait, in points.
    static let windowSize = CGSize(width: 402, height: 874)
    /// References are stored at 1x to keep the files small in git.
    static let scale: CGFloat = 1

    /// A channel may differ by this much (0–255) before the pixel counts as changed.
    static let channelTolerance = 8
    /// Share of changed pixels that still passes, for anti-aliasing noise.
    static let changedPixelTolerance = 0.002

    static var isReferenceDevice: Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
        return model == referenceModel
            && version.majorVersion == referenceOS.major
            && version.minorVersion == referenceOS.minor
    }

    enum Layout {
        /// The whole window, safe areas included.
        case screen
        /// The window's width and the view's own height, laid out at the top, without safe areas.
        case fitting
    }

    /// Renders `view` in light or dark mode and checks it against `__Snapshots__/<name>.png`.
    @MainActor
    static func assert(
        _ view: some View,
        named name: String,
        style: UIUserInterfaceStyle = .light,
        layout: Layout = .screen,
        filePath: String = #filePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        let image = try await render(view, style: style, layout: layout)
        let fileName = "\(name)-\(style == .dark ? "dark" : "light").png"
        let url = URL(filePath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "__Snapshots__")
            .appending(path: fileName)

        guard let reference = UIImage(contentsOfFile: url.path(percentEncoded: false)) else {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try #require(image.pngData()).write(to: url)
            Issue.record(
                "Recorded a new reference at \(url.path(percentEncoded: false)). Check it, then run again.",
                sourceLocation: sourceLocation
            )
            return
        }

        if let difference = compare(image, reference) {
            let failureURL = URL.temporaryDirectory.appending(path: fileName)
            try? image.pngData()?.write(to: failureURL)
            Issue.record(
                """
                \(fileName) differs from its reference: \(difference). \
                The new rendering is at \(failureURL.path(percentEncoded: false)).
                """,
                sourceLocation: sourceLocation
            )
        }
    }

    // MARK: Rendering

    @MainActor
    private static func render(_ view: some View, style: UIUserInterfaceStyle, layout: Layout) async throws -> UIImage {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "The test host has no window scene."
        )
        let content = view
            .environment(\.locale, Locale(identifier: "en_GB"))
            .environment(\.dynamicTypeSize, .large)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        let controller = UIHostingController(rootView: content)
        controller.view.backgroundColor = .systemBackground
        if layout == .fitting {
            controller.safeAreaRegions = []
        }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: windowSize)
        window.overrideUserInterfaceStyle = style
        window.rootViewController = controller
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        // Let appear animations, symbol effects and fades settle before drawing.
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(700))
        controller.view.layoutIfNeeded()

        var size = windowSize
        if layout == .fitting {
            let fitting = controller.sizeThatFits(in: CGSize(width: windowSize.width, height: .infinity))
            size.height = min(fitting.height.rounded(.up), windowSize.height)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    // MARK: Comparing

    /// nil when the images match within the tolerances, otherwise a description of how they differ.
    private static func compare(_ image: UIImage, _ reference: UIImage) -> String? {
        guard let new = pixels(of: image), let old = pixels(of: reference) else { return "unreadable image" }
        guard new.width == old.width, new.height == old.height else {
            return "size \(new.width)×\(new.height) instead of \(old.width)×\(old.height)"
        }
        var changed = 0
        for pixel in stride(from: 0, to: new.bytes.count, by: 4) {
            let differs = (pixel..<pixel + 4).contains { index in
                abs(Int(new.bytes[index]) - Int(old.bytes[index])) > channelTolerance
            }
            if differs { changed += 1 }
        }
        let share = Double(changed) / Double(new.width * new.height)
        guard share > changedPixelTolerance else { return nil }
        return String(format: "%.2f%% of the pixels changed", share * 100)
    }

    /// RGBA bytes in sRGB, so a reference read from disk and a fresh rendering are compared like for like.
    private static func pixels(of image: UIImage) -> Pixels? {
        guard let cgImage = image.cgImage, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? Pixels(width: width, height: height, bytes: bytes) : nil
    }

    private struct Pixels {
        let width: Int
        let height: Int
        let bytes: [UInt8]
    }
}

extension Trait where Self == ConditionTrait {
    /// Runs snapshot tests only where the references were recorded, and skips them with a reason elsewhere.
    static var snapshotDevice: Self {
        .enabled(
            if: Snapshot.isReferenceDevice,
            """
            Snapshot references were recorded on an \(Snapshot.referenceModelName) simulator \
            (\(Snapshot.referenceModel)) running iOS \(Snapshot.referenceOS.major).\(Snapshot.referenceOS.minor); \
            rendering differs elsewhere.
            """
        )
    }
}
