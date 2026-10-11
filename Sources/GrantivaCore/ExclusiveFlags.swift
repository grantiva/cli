import Foundation

/// Two flags a command cannot take together. One sentence and one check for
/// every such pair (`--device`/`--emulator`, `--session-id`/`--udid`,
/// `--serial`/`--all`), so each is the same usage error everywhere (L26-b).
public enum ExclusiveFlags {
    /// `<first> and <second> are mutually exclusive; pass one.`
    public static func message(_ first: String, _ second: String) -> String {
        "\(first) and \(second) are mutually exclusive; pass one."
    }

    /// The message when both flags were given, else nil.
    public static func problem(_ first: (flag: String, given: Bool), _ second: (flag: String, given: Bool)) -> String? {
        first.given && second.given ? message(first.flag, second.flag) : nil
    }
}
