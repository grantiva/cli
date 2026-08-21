import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Repairs the known one-column runner crop without hiding arbitrary capture
/// size errors. The replacement column repeats the trailing source column,
/// which preserves all source pixels and avoids resampling the screenshot.
public enum ScreenshotNormalizer {
    enum Correction: Equatable {
        case extendTrailingColumn
    }

    static func correction(sourceWidth: Int, sourceHeight: Int, expectedWidth: Int, expectedHeight: Int) -> Correction? {
        guard sourceHeight == expectedHeight, sourceWidth + 1 == expectedWidth else { return nil }
        return .extendTrailingColumn
    }

    public static func normalize(captures: [ScreenCapture], expectedPixels: SimulatorProvisionResult.Dimensions) throws {
        for capture in captures where !capture.path.isEmpty {
            try normalizePNG(
                at: capture.path,
                expectedWidth: expectedPixels.width,
                expectedHeight: expectedPixels.height
            )
        }
    }

    private static func normalizePNG(at path: String, expectedWidth: Int, expectedHeight: Int) throws {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              correction(sourceWidth: image.width, sourceHeight: image.height, expectedWidth: expectedWidth, expectedHeight: expectedHeight) != nil
        else { return }

        guard let context = CGContext(
            data: nil,
            width: expectedWidth,
            height: expectedHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw GrantivaError.commandFailed("Could not create exact-target screenshot context", 1)
        }

        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        if let trailingColumn = image.cropping(to: CGRect(x: image.width - 1, y: 0, width: 1, height: image.height)) {
            context.draw(trailingColumn, in: CGRect(x: image.width, y: 0, width: 1, height: image.height))
        }
        guard let normalized = context.makeImage() else {
            throw GrantivaError.commandFailed("Could not render exact-target screenshot", 1)
        }

        let replacement = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).normalized")
        guard let destination = CGImageDestinationCreateWithURL(replacement as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw GrantivaError.commandFailed("Could not write exact-target screenshot", 1)
        }
        CGImageDestinationAddImage(destination, normalized, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw GrantivaError.commandFailed("Could not finalize exact-target screenshot", 1)
        }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: replacement)
    }
}
