import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import GrantivaCore

final class ScreenshotNormalizerTests: XCTestCase {
    func testRepairsOnlyTheKnownOneTrailingColumnCrop() {
        XCTAssertEqual(
            ScreenshotNormalizer.correction(sourceWidth: 1178, sourceHeight: 2556, expectedWidth: 1179, expectedHeight: 2556),
            .extendTrailingColumn
        )
    }

    func testLeavesAllOtherDimensionMismatchesUntouched() {
        XCTAssertNil(ScreenshotNormalizer.correction(sourceWidth: 1177, sourceHeight: 2556, expectedWidth: 1179, expectedHeight: 2556))
        XCTAssertNil(ScreenshotNormalizer.correction(sourceWidth: 1179, sourceHeight: 2556, expectedWidth: 1179, expectedHeight: 2556))
        XCTAssertNil(ScreenshotNormalizer.correction(sourceWidth: 1178, sourceHeight: 2555, expectedWidth: 1179, expectedHeight: 2556))
    }

    func testExtendsTheTrailingColumnWithoutResamplingTheImage() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-normalizer-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: path) }
        try writePNG(width: 2, height: 2, pixels: [
            10, 0, 0, 255, 20, 0, 0, 255,
            30, 0, 0, 255, 40, 0, 0, 255,
        ], to: path)

        try ScreenshotNormalizer.normalize(
            captures: [.init(screenName: "fixture", path: path.path, sizeBytes: 0)],
            expectedPixels: .init(width: 3, height: 2)
        )

        let image = try XCTUnwrap(CGImageSourceCreateWithURL(path as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
        XCTAssertEqual(image.width, 3)
        XCTAssertEqual(image.height, 2)
        let pixels = try rgbaPixels(image)
        XCTAssertEqual(pixels[0], 10)
        XCTAssertEqual(pixels[4], 20)
        XCTAssertEqual(pixels[8], 20)
        XCTAssertEqual(pixels[12], 30)
        XCTAssertEqual(pixels[16], 40)
        XCTAssertEqual(pixels[20], 40)
    }

    private func writePNG(width: Int, height: Int, pixels: [UInt8], to url: URL) throws {
        var mutablePixels = pixels
        guard let context = CGContext(
            data: &mutablePixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
           let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw XCTSkip("Could not construct PNG fixture") }
        guard let populated = context.makeImage() else { throw XCTSkip("Could not render PNG fixture") }
        CGImageDestinationAddImage(destination, populated, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func rgbaPixels(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let context = CGContext(
            data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw XCTSkip("Could not read PNG fixture") }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixels
    }
}
