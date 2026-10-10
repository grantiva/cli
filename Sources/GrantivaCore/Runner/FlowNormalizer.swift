import Foundation

/// Rewrites standard Maestro command forms that the bundled runner does not
/// handle into equivalent forms it does, before a flow is staged:
///
/// - bare `scroll` gets `direction: DOWN` (the runner rejects an empty direction);
/// - `setPermissions` without its own `appId` gets the flow header's `appId`;
/// - `swipe: {from: X}` becomes `swipe: {selector: X}` (the runner drops `from`
///   and would swipe across the screen centre instead of on the element).
enum FlowNormalizer {
    static func normalize(_ command: Any, headerAppId: String?) -> Any {
        if let bare = command as? String {
            return bare == "scroll" ? ["scroll": ["direction": "DOWN"]] : command
        }
        guard var dictionary = command as? [String: Any] else { return command }

        if dictionary.keys.contains("setPermissions"), let headerAppId {
            var options = dictionary["setPermissions"] as? [String: Any] ?? [:]
            if options["appId"] == nil {
                options["appId"] = headerAppId
                dictionary["setPermissions"] = options
            }
        }

        if var swipe = dictionary["swipe"] as? [String: Any], let from = swipe["from"] {
            swipe.removeValue(forKey: "from")
            if swipe["selector"] == nil {
                swipe["selector"] = from
            }
            dictionary["swipe"] = swipe
        }
        return dictionary
    }
}
