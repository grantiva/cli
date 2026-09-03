import XCTest
@testable import GrantivaAPI

final class NetworkClientTests: XCTestCase {
    private struct Patch: Encodable { let title: String }
    private struct Reply: Decodable { let ok: Bool }

    private final class Recorder: @unchecked Sendable {
        var requests: [URLRequest] = []
        var calls: [String] = []
    }

    private func client(recording recorder: Recorder) -> NetworkClient {
        NetworkClient(
            get: { _ in recorder.calls.append("get"); return Data("{\"ok\":true}".utf8) },
            post: { _, _ in recorder.calls.append("post"); return Data("{\"ok\":true}".utf8) },
            put: { _, _ in recorder.calls.append("put"); return Data("{\"ok\":true}".utf8) },
            delete: { _ in recorder.calls.append("delete"); return Data("{\"ok\":true}".utf8) },
            sendRequest: { request in
                recorder.calls.append("sendRequest")
                recorder.requests.append(request)
                return Data("{\"ok\":true}".utf8)
            }
        )
    }

    func testPatchIsSentAsPatchNotPut() async throws {
        let recorder = Recorder()
        let endpoint = Endpoint<Patch, Reply>(path: "api/v1/things/1", method: .patch, body: Patch(title: "t"))

        let reply = try await client(recording: recorder).execute(endpoint, baseURL: URL(string: "https://api.example")!)

        XCTAssertTrue(reply.ok)
        XCTAssertEqual(recorder.calls, ["sendRequest"])
        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.absoluteString, "https://api.example/api/v1/things/1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.httpBody, Data("{\"title\":\"t\"}".utf8))
    }

    func testPutStillUsesThePutClosure() async throws {
        let recorder = Recorder()
        let endpoint = Endpoint<Patch, Reply>(path: "api/v1/things/1", method: .put, body: Patch(title: "t"))
        _ = try await client(recording: recorder).execute(endpoint, baseURL: URL(string: "https://api.example")!)
        XCTAssertEqual(recorder.calls, ["put"])
    }

    func testDownloadUsesRawAcceptHeaderAndLongTimeout() async throws {
        let recorder = Recorder()
        let endpoint = Endpoint<EmptyBody, EmptyResponse>(path: "exports/report.csv", method: .get)

        _ = try await client(recording: recorder).download(
            endpoint,
            baseURL: URL(string: "https://api.example")!
        )

        XCTAssertEqual(recorder.calls, ["sendRequest"])
        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "*/*")
        XCTAssertEqual(request.timeoutInterval, 300)
    }
}

final class MultipartFormTests: XCTestCase {
    func testCaptureAndDiffPartsAreIndexedByScreenPosition() {
        let upload = RunUpload(
            branch: "main", trigger: "ci", duration: 1,
            screens: [
                RunScreenUpload(name: "Home", status: "passed", pixelThreshold: 0.1, perceptualThreshold: 0.1,
                                captureData: Data("home".utf8)),
                RunScreenUpload(name: "Settings", status: "failed", pixelThreshold: 0.1, perceptualThreshold: 0.1,
                                captureData: Data("settings".utf8), diffData: Data("diff".utf8)),
            ]
        )

        let body = String(decoding: MultipartForm.build(from: upload).data, as: UTF8.self)

        XCTAssertTrue(body.contains("name=\"captures[0]\"; filename=\"Home.png\""), body)
        XCTAssertTrue(body.contains("name=\"captures[1]\"; filename=\"Settings.png\""), body)
        XCTAssertTrue(body.contains("name=\"diffs[1]\"; filename=\"Settings_diff.png\""), body)
        XCTAssertFalse(body.contains("diffs[0]"), body)
    }
}
