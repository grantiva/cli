import Foundation
import XCTest
@testable import GrantivaCore

/// Records every HTTP request and answers from a script. Mirrors ScriptedShell.
final class ScriptedTransport: @unchecked Sendable {
    struct Call: Equatable { let method: String; let path: String; let body: String }
    private let lock = NSLock()
    private var answers: [(Data, Int)]
    private var recorded: [Call] = []
    init(_ answers: [(String, Int)]) { self.answers = answers.map { (Data($0.0.utf8), $0.1) } }
    var calls: [Call] { lock.withLock { recorded } }
    var transport: UIAutomator2Transport {
        UIAutomator2Transport { request in
            self.lock.withLock {
                let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
                self.recorded.append(Call(method: request.httpMethod ?? "GET", path: request.url?.path ?? "", body: body))
                guard !self.answers.isEmpty else { return (Data("{}".utf8), 200) }
                return self.answers.removeFirst()
            }
        }
    }
}

final class UIAutomator2ClientTests: XCTestCase {
    private let sessions = #"{"sessionId":"None","value":[{"id":"abc-123","capabilities":{}}]}"#
    private let noSessions = #"{"sessionId":"None","value":[]}"#

    private func adb(_ shell: ScriptedShell) -> ADB { ADB(path: "/sdk/platform-tools/adb", execute: shell.execute) }

    func testAttachForwardsAPortAndReadsTheSessionID() async throws {
        let shell = ScriptedShell([.success("61211")])
        let transport = ScriptedTransport([(sessions, 200)])
        let endpoint = try await UIAutomator2.attach(adb: adb(shell), serial: "emulator-5554", transport: transport.transport)
        XCTAssertEqual(endpoint, UIAutomator2Endpoint(localPort: 61211, sessionID: "abc-123"))
        XCTAssertEqual(endpoint.baseURL, "http://127.0.0.1:61211/wd/hub")
        XCTAssertEqual(shell.commands, ["'/sdk/platform-tools/adb' -s 'emulator-5554' forward tcp:0 tcp:6790"])
        XCTAssertEqual(transport.calls.map(\.path), ["/wd/hub/sessions"])
    }

    /// Review Focus 1.
    func testAttachRemovesTheForwardWhenNoSessionExists() async {
        let shell = ScriptedShell([.success("61211"), .success("")])
        let transport = ScriptedTransport([(noSessions, 200)])
        do {
            _ = try await UIAutomator2.attach(adb: adb(shell), serial: "emulator-5554", transport: transport.transport)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("No UIAutomator2 session on emulator-5554"), "\(error)")
            XCTAssertTrue("\(error)".contains("grantiva run --keep-alive"), "\(error)")
        }
        XCTAssertEqual(shell.commands.last, "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --remove tcp:61211")
    }

    func testAttachRemovesTheForwardWhenTheServerDoesNotAnswer() async {
        let shell = ScriptedShell([.success("61211"), .success("")])
        let transport = UIAutomator2Transport { _ in throw URLError(.cannotConnectToHost) }
        do {
            _ = try await UIAutomator2.attach(adb: adb(shell), serial: "emulator-5554", transport: transport)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("not answering"), "\(error)")
        }
        XCTAssertEqual(shell.commands.count, 2)
    }

    func testEndpointForAKnownLocalPortSkipsTheForward() async throws {
        let shell = ScriptedShell()
        let transport = ScriptedTransport([(sessions, 200)])
        let endpoint = try await UIAutomator2.endpoint(localPort: 7000, serial: "emulator-5554", transport: transport.transport)
        XCTAssertEqual(endpoint.sessionID, "abc-123")
        XCTAssertTrue(shell.commands.isEmpty)
    }

    /// Review Focus 2.
    func testXPathLiteralHandlesBothQuoteKinds() {
        XCTAssertEqual(UIAutomator2.xpathLiteral("Sign in"), "\"Sign in\"")
        XCTAssertEqual(UIAutomator2.xpathLiteral("It's"), "\"It's\"")
        XCTAssertEqual(UIAutomator2.xpathLiteral("Say \"hi\""), "'Say \"hi\"'")
        XCTAssertEqual(UIAutomator2.xpathLiteral("It's \"ok\""), "concat(\"It's \", '\"', \"ok\", '\"', \"\")")
        XCTAssertEqual(UIAutomator2.labelXPath("Details"), "//*[@content-desc=\"Details\" or @text=\"Details\"]")
    }

    private func client(_ transport: ScriptedTransport, scale: Double = 2) -> DriverClient {
        DriverClient.uiAutomator2(endpoint: UIAutomator2Endpoint(localPort: 7000, sessionID: "abc-123"), scale: scale, transport: transport.transport)
    }

    func testHierarchyXMLUnwrapsTheValue() async throws {
        let transport = ScriptedTransport([(#"{"sessionId":"abc-123","value":"<hierarchy><android.view.View class=\"android.view.View\" text=\"Hi\" bounds=\"[0,0][20,40]\"/></hierarchy>"}"#, 200)])
        let xml = try await client(transport).hierarchyXML()
        XCTAssertTrue(xml.hasPrefix("<hierarchy>"))
        XCTAssertEqual(transport.calls, [.init(method: "GET", path: "/wd/hub/session/abc-123/source", body: "")])
    }

    func testHierarchyParsesWithTheScale() async throws {
        let transport = ScriptedTransport([(#"{"value":"<hierarchy><android.view.View class=\"android.view.View\" text=\"Hi\" bounds=\"[0,0][20,40]\"/></hierarchy>"}"#, 200)])
        let tree = try await client(transport, scale: 2).hierarchy()
        let child = try XCTUnwrap((tree["children"] as? [[String: Any]])?.first)
        XCTAssertEqual(child["frame"] as? [String: String], ["x": "0", "y": "0", "width": "10", "height": "20"])
    }

    func testTapByLabelFindsByXPathThenClicks() async throws {
        let transport = ScriptedTransport([
            (#"{"value":[{"ELEMENT":"e1","element-6066-11e4-a52e-4f735466cecf":"e1"}]}"#, 200),
            (#"{"value":null}"#, 200),
        ])
        try await client(transport).tapByLabel("Details")
        XCTAssertEqual(transport.calls.map(\.path), ["/wd/hub/session/abc-123/elements", "/wd/hub/session/abc-123/element/e1/click"])
        XCTAssertEqual(transport.calls[0].method, "POST")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(transport.calls[0].body.utf8)) as? [String: String])
        XCTAssertEqual(body, ["strategy": "xpath", "selector": "//*[@content-desc=\"Details\" or @text=\"Details\"]"])
    }

    func testTapByLabelReportsAMissingElement() async {
        let transport = ScriptedTransport([(#"{"value":[]}"#, 200)])
        do {
            try await client(transport).tapByLabel("Nope")
            XCTFail("expected an error")
        } catch let error as GrantivaError {
            guard case .elementNotFound("Nope") = error else { return XCTFail("\(error)") }
        } catch { XCTFail("\(error)") }
    }

    func testTapByCoordinateSendsPixelPointerActions() async throws {
        let transport = ScriptedTransport([(#"{"value":null}"#, 200)])
        try await client(transport).tapByCoordinate(540, 1200)
        XCTAssertEqual(transport.calls.map(\.path), ["/wd/hub/session/abc-123/actions"])
        XCTAssertTrue(transport.calls[0].body.contains(#""x":540"#), transport.calls[0].body)
        XCTAssertTrue(transport.calls[0].body.contains(#""pointerType":"touch""#), transport.calls[0].body)
    }

    func testTypeTextSendsKeyActionsPerCharacter() async throws {
        let transport = ScriptedTransport([(#"{"value":null}"#, 200)])
        try await client(transport).typeText("hi")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(transport.calls[0].body.utf8)) as? [String: Any])
        let actions = try XCTUnwrap((body["actions"] as? [[String: Any]])?.first)
        XCTAssertEqual(actions["type"] as? String, "key")
        let steps = try XCTUnwrap(actions["actions"] as? [[String: String]])
        XCTAssertEqual(steps, [
            ["type": "keyDown", "value": "h"], ["type": "keyUp", "value": "h"],
            ["type": "keyDown", "value": "i"], ["type": "keyUp", "value": "i"],
        ])
    }

    func testSwipeReadsTheWindowSizeInPixels() async throws {
        let transport = ScriptedTransport([(#"{"value":{"width":1080,"height":2400}}"#, 200), (#"{"value":null}"#, 200)])
        try await client(transport).swipe("up")
        XCTAssertEqual(transport.calls.map(\.path), ["/wd/hub/session/abc-123/window/current/size", "/wd/hub/session/abc-123/actions"])
        XCTAssertTrue(transport.calls[1].body.contains(#""y":1680"#), "0.7 * 2400: \(transport.calls[1].body)")
        XCTAssertTrue(transport.calls[1].body.contains(#""y":720"#), "0.3 * 2400: \(transport.calls[1].body)")
    }

    func testSwipeRejectsAnUnknownDirection() async {
        let transport = ScriptedTransport([(#"{"value":{"width":1080,"height":2400}}"#, 200)])
        do {
            try await client(transport).swipe("sideways")
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("Invalid swipe direction"), "\(error)")
        }
    }

    func testScreenshotDecodesBase64() async throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString()
        let transport = ScriptedTransport([(#"{"value":"\#(png)"}"#, 200)])
        let data = try await client(transport).screenshot()
        XCTAssertEqual([UInt8](data), [0x89, 0x50, 0x4E, 0x47])
        XCTAssertEqual(transport.calls.map(\.path), ["/wd/hub/session/abc-123/screenshot"])
    }

    func testStatusReportsReadyAndTheSession() async throws {
        let transport = ScriptedTransport([(#"{"sessionId":"None","value":{"ready":true}}"#, 200)])
        let status = try await client(transport).status()
        XCTAssertEqual(status.sessionId, "abc-123")
        XCTAssertTrue(status.ready)
    }

    func testANon200AnswerIsAnError() async {
        let transport = ScriptedTransport([(#"{"value":{"error":"unknown command"}}"#, 404)])
        do {
            _ = try await client(transport).hierarchyXML()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("HTTP 404"), "\(error)")
        }
    }
}
