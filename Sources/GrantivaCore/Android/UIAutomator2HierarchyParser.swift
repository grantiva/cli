import Foundation

/// Parses the UIAutomator2 page source into the same dictionary tree
/// `WDAHierarchyXMLParser` produces, so `dump-hierarchy`, the MCP tools, and
/// the a11y rules read one shape on both platforms.
///
/// Mapping: `class` → `type`; `content-desc` then `text` → `label`;
/// `content-desc` → `name`; `resource-id` → `identifier`; `text` → `value`;
/// `enabled`, `displayed` → `enabled`, `visible`; `clickable` → `clickable`;
/// `bounds="[x1,y1][x2,y2]"` (pixels) → `frame` in dp using `scale`.
public final class UIAutomator2HierarchyXMLParser: NSObject, XMLParserDelegate {
    private let xml: String
    private let scale: Double
    private var stack: [NSMutableDictionary] = []
    private var root: [String: Any] = [:]
    private var conversionFailed = false

    public init(xml: String, scale: Double) {
        self.xml = xml
        self.scale = scale > 0 ? scale : 1
    }

    public func parse() throws -> [String: Any] {
        guard let data = xml.data(using: .utf8) else {
            throw GrantivaError.commandFailed("Failed to encode UIAutomator2 hierarchy XML", 1)
        }
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse(), !conversionFailed, !root.isEmpty else {
            let detail = parser.parserError?.localizedDescription ?? "unexpected hierarchy structure"
            throw GrantivaError.commandFailed("Failed to parse UIAutomator2 hierarchy XML: \(detail)", 1)
        }
        return root
    }

    /// `[x1,y1][x2,y2]` → origin and size in pixels.
    public static func parseBounds(_ value: String) -> (x: Int, y: Int, width: Int, height: Int)? {
        let numbers = value.split(whereSeparator: { !$0.isNumber && $0 != "-" }).compactMap { Int($0) }
        guard numbers.count == 4 else { return nil }
        return (numbers[0], numbers[1], numbers[2] - numbers[0], numbers[3] - numbers[1])
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String,
                       namespaceURI: String?, qualifiedName: String?,
                       attributes: [String: String]) {
        let node = NSMutableDictionary()
        node["type"] = attributes["class"].flatMap { $0.isEmpty ? nil : $0 } ?? elementName
        if stack.isEmpty { node["platform"] = "android" }

        let text = attributes["text"] ?? ""
        let desc = attributes["content-desc"] ?? ""
        if !desc.isEmpty {
            node["label"] = desc
            node["name"] = desc
        } else if !text.isEmpty {
            node["label"] = text
        }
        if let id = attributes["resource-id"], !id.isEmpty { node["identifier"] = id }
        if !text.isEmpty { node["value"] = text }
        if let package = attributes["package"], !package.isEmpty { node["package"] = package }
        if let enabled = attributes["enabled"] { node["enabled"] = enabled == "true" }
        if let displayed = attributes["displayed"] { node["visible"] = displayed == "true" }
        if let clickable = attributes["clickable"] { node["clickable"] = clickable == "true" }
        if let bounds = attributes["bounds"], let b = Self.parseBounds(bounds) {
            func dp(_ px: Int) -> String { String(Int((Double(px) / scale).rounded())) }
            node["frame"] = ["x": dp(b.x), "y": dp(b.y), "width": dp(b.width), "height": dp(b.height)]
        }
        node["children"] = NSMutableArray()

        if let parent = stack.last {
            (parent["children"] as? NSMutableArray)?.add(node)
        }
        stack.append(node)
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String,
                       namespaceURI: String?, qualifiedName: String?) {
        if let finished = stack.popLast(), stack.isEmpty {
            guard let dictionary = finished as? [String: Any] else {
                conversionFailed = true
                return
            }
            root = dictionary
        }
    }
}
