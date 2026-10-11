import Foundation

/// The AVD name `init` writes into grantiva-android.yml and doctor and
/// `scripts/android-env.sh` suggest. A stock name, so the user may already
/// own an AVD called that: `init` warns when one exists that Grantiva did not
/// create (L09).
public enum DefaultEmulator {
    public static let name = "Pixel_8_API_35"

    /// The Grantiva-specific name suggested in its place (an AVD name allows
    /// no spaces).
    public static func grantivaName(for name: String) -> String { "Grantiva_\(name)" }
}
