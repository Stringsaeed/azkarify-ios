import CryptoKit
import Foundation
import Testing

@testable import azkarify

@Suite(.serialized)
struct CountriesAPIClientTests {
  private let baseURL = URL(string: "https://api.example.test/v1")!

  @Test func unsupportedDeviceDoesNotContactAuthenticationEndpoints() async throws {
    let attestor = FakeAttestor(isSupported: false)
    let transport = RecordingCountriesTransport { _, _ in
      fatalError("An unsupported device must not make a remote request.")
    }
    let client = try CountriesAPIClient(
      baseURL: baseURL,
      defaults: makeDefaults(),
      attestor: attestor,
      transport: transport,
      sleeper: noSleep)

    do {
      _ = try await client.data(for: request(path: "/v1/countries.json"))
      Issue.record("Expected unsupportedDevice")
    } catch let error as CountriesAPIClient.ClientError {
      guard case .unsupportedDevice = error else {
        Issue.record("Unexpected error: \(error)")
        return
      }
    }

    #expect(transport.requests.isEmpty)
    #expect(attestor.generateKeyCount == 0)
  }

  @Test func canonicalPayloadUsesExactURLHeadersAndNoTrailingNewline() throws {
    var request = request(path: "/v1/countries.json?limit=1")
    request.setValue("ar", forHTTPHeaderField: "Accept-Language")
    request.setValue("\"v1\"", forHTTPHeaderField: "If-None-Match")

    let payload = try CountriesAPIClient.canonicalAssertionPayload(
      for: request,
      challenge: "abc")
    #expect(payload == "countries-api:v1\nGET\nhttps://api.example.test/v1/countries.json?limit=1\nar\n\"v1\"\nabc")
    #expect(!payload.hasSuffix("\n"))

    let hash = try CountriesAPIClient.assertionClientDataHash(for: request, challenge: "abc")
    #expect(hash.hexString == "950dfcbe7342aa89bbd138b8123814c668b3c7258e9ec9824e0aba8a01f13513")
  }

  @Test func enrollmentUsesV1RootAndPersistsOnlyAfter204() async throws {
    let attestor = FakeAttestor(isSupported: true)
    let transport = RecordingCountriesTransport { request, occurrence in
      switch request.url?.path {
      case "/v1/auth/challenge":
        return .response(status: 200, headers: [:], body: challengeBody("attestation-challenge"))
      case "/v1/auth/attest":
        // A 200 is not a successful enrollment. The following attempt must
        // retry the persisted attestation object and require 204.
        return .response(status: occurrence == 3 ? 204 : 200, headers: [:], body: Data())
      case "/v1/countries.json":
        return .response(status: 200, headers: [:], body: Data(#"{"ok":true}"#.utf8))
      default:
        Issue.record("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
        return .response(status: 500, headers: [:], body: Data())
      }
    }
    let client = try CountriesAPIClient(
      baseURL: baseURL,
      environment: "staging",
      defaults: makeDefaults(),
      attestor: attestor,
      transport: transport,
      sleeper: noSleep)

    let firstRequest = request(path: "/v1/countries.json")
    do {
      _ = try await client.data(for: firstRequest)
      Issue.record("Expected non-204 enrollment to fail")
    } catch let error as CountriesAPIClient.ClientError {
      guard case .httpStatus(200, _) = error else {
        Issue.record("Unexpected error: \(error)")
        return
      }
    }

    #expect(attestor.generateKeyCount == 1)
    #expect(attestor.attestationCount == 1)
    #expect(transport.requests.map { $0.url?.path } == ["/v1/auth/challenge", "/v1/auth/attest"])

    let result = try await client.data(for: firstRequest)
    #expect(result.1.statusCode == 200)
    #expect(attestor.generateKeyCount == 1)
    #expect(attestor.attestationCount == 1)
    #expect(transport.requests.map { $0.url?.path } == [
      "/v1/auth/challenge",
      "/v1/auth/attest",
      "/v1/auth/attest",
      "/v1/auth/challenge",
      "/v1/countries.json",
    ])
  }

  @Test func environmentNamespacesKeepEnrollmentKeysSeparate() async throws {
    let attestor = FakeAttestor(isSupported: true)
    let transport = RecordingCountriesTransport { request, occurrence in
      switch request.url?.path {
      case "/v1/auth/challenge":
        let body = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let purpose = try #require(object["purpose"] as? String)
        return .response(
          status: 200,
          headers: [:],
          body: challengeBody(purpose == "attestation" ? "attest-\(occurrence)" : "assert-\(occurrence)"))
      case "/v1/auth/attest":
        return .response(status: 204, headers: [:], body: Data())
      case "/v1/countries.json":
        return .response(status: 200, headers: [:], body: Data(#"{"ok":true}"#.utf8))
      default:
        return .response(status: 500, headers: [:], body: Data())
      }
    }
    let defaults = makeDefaults()
    let staging = try CountriesAPIClient(
      baseURL: baseURL,
      environment: "staging",
      defaults: defaults,
      attestor: attestor,
      transport: transport,
      sleeper: noSleep)
    let production = try CountriesAPIClient(
      baseURL: baseURL,
      environment: "production",
      defaults: defaults,
      attestor: attestor,
      transport: transport,
      sleeper: noSleep)

    _ = try await staging.data(for: request(path: "/v1/countries.json"))
    _ = try await production.data(for: request(path: "/v1/countries.json"))

    #expect(attestor.generateKeyCount == 2)
    #expect(attestor.attestationCount == 2)
  }

  @Test func expiredPendingEnrollmentProbesBeforeCreatingAnotherKey() async throws {
    let attestor = FakeAttestor(isSupported: true)
    let transport = RecordingCountriesTransport { request, occurrence in
      switch request.url?.path {
      case "/v1/auth/challenge":
        let body = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let purpose = try #require(object["purpose"] as? String)
        let expiry = purpose == "attestation"
          ? "2020-01-01T00:00:00.000Z"
          : "2099-01-01T00:00:00.000Z"
        return .response(status: 200, headers: [:], body: challengeBody(
          purpose == "attestation" ? "attest" : "probe-or-assertion",
          expiresAt: expiry))
      case "/v1/auth/attest":
        if occurrence == 2 {
          throw URLError(.networkConnectionLost)
        }
        return .response(status: 204, headers: [:], body: Data())
      case "/v1/countries.json":
        return .response(status: 200, headers: [:], body: Data(#"{"ok":true}"#.utf8))
      default:
        return .response(status: 500, headers: [:], body: Data())
      }
    }
    let client = try CountriesAPIClient(
      baseURL: baseURL,
      defaults: makeDefaults(),
      attestor: attestor,
      transport: transport,
      sleeper: noSleep)

    _ = try await client.data(for: request(path: "/v1/countries.json"))
    #expect(attestor.generateKeyCount == 1)
    #expect(attestor.attestationCount == 1)
    #expect(transport.requests.map { $0.url?.path } == [
      "/v1/auth/challenge",
      "/v1/auth/attest",
      "/v1/auth/challenge",
      "/v1/auth/challenge",
      "/v1/countries.json",
    ])
  }

  @Test func unauthorizedResponseGetsOneFreshChallengeAndAssertion() async throws {
    let attestor = FakeAttestor(isSupported: true)
    let transport = RecordingCountriesTransport { request, occurrence in
      switch request.url?.path {
      case "/v1/auth/challenge":
        let body = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let purpose = try #require(object["purpose"] as? String)
        if purpose == "attestation" {
          return .response(status: 200, headers: [:], body: challengeBody("attest"))
        }
        let challengeNumber = occurrence == 3 ? 1 : 2
        return .response(
          status: 200,
          headers: [:],
          body: challengeBody("assertion-\(challengeNumber)"))
      case "/v1/auth/attest":
        return .response(status: 204, headers: [:], body: Data())
      case "/v1/countries.json":
        if occurrence == 4 {
          return .response(
            status: 401,
            headers: ["Content-Type": "application/problem+json"],
            body: Data(#"{"code":"unauthorized"}"#.utf8))
        }
        return .response(status: 200, headers: [:], body: Data(#"{"ok":true}"#.utf8))
      default:
        Issue.record("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
        return .response(status: 500, headers: [:], body: Data())
      }
    }
    let client = try CountriesAPIClient(
      baseURL: baseURL,
      defaults: makeDefaults(),
      attestor: attestor,
      transport: transport,
      sleeper: noSleep)

    let result = try await client.data(for: request(path: "/v1/countries.json"))
    #expect(result.1.statusCode == 200)
    #expect(attestor.generateKeyCount == 1)
    #expect(attestor.assertionCount == 2)

    let assertionChallenges = transport.requests.compactMap { request -> String? in
      guard request.url?.path == "/v1/countries.json" else { return nil }
      return request.value(forHTTPHeaderField: "X-App-Attest-Challenge")
    }
    #expect(assertionChallenges == ["assertion-1", "assertion-2"])
  }

  @Test func transientEnrollmentFailureKeepsGeneratedKeyAndRetriesBoundedly() async throws {
    let attestor = FakeAttestor(isSupported: true)
    let transport = RecordingCountriesTransport { request, occurrence in
      switch request.url?.path {
      case "/v1/auth/challenge":
        if occurrence == 1 {
          throw URLError(.timedOut)
        }
        return .response(status: 200, headers: [:], body: challengeBody("attest"))
      case "/v1/auth/attest":
        return .response(status: 204, headers: [:], body: Data())
      case "/v1/countries.json":
        return .response(status: 200, headers: [:], body: Data(#"{"ok":true}"#.utf8))
      default:
        return .response(status: 500, headers: [:], body: Data())
      }
    }
    let sleeps = LockedValues<UInt64>()
    let client = try CountriesAPIClient(
      baseURL: baseURL,
      defaults: makeDefaults(),
      attestor: attestor,
      transport: transport,
      sleeper: { nanoseconds in sleeps.append(nanoseconds) })

    _ = try await client.data(for: request(path: "/v1/countries.json"))
    #expect(attestor.generateKeyCount == 1)
    #expect(attestor.attestationCount == 1)
    #expect(sleeps.values == [250_000_000])
  }

  @Test func concurrentRequestsSerializeAssertionGenerationAndHTTPDelivery() async throws {
    let attestor = FakeAttestor(isSupported: true, assertionDelayNanoseconds: 1_000_000)
    let transport = RecordingCountriesTransport { request, _ in
      switch request.url?.path {
      case "/v1/auth/challenge":
        let body = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let purpose = try #require(object["purpose"] as? String)
        return .response(
          status: 200,
          headers: [:],
          body: challengeBody(purpose == "attestation" ? "attest" : "assertion"))
      case "/v1/auth/attest":
        return .response(status: 204, headers: [:], body: Data())
      case "/v1/countries.json":
        return .response(status: 200, headers: [:], body: Data(#"{"ok":true}"#.utf8))
      default:
        return .response(status: 500, headers: [:], body: Data())
      }
    }
    let client = try CountriesAPIClient(
      baseURL: baseURL,
      defaults: makeDefaults(),
      attestor: attestor,
      transport: transport,
      sleeper: noSleep)

    async let first = client.data(for: request(path: "/v1/countries.json?cursor=one"))
    async let second = client.data(for: request(path: "/v1/countries.json?cursor=two"))
    _ = try await first
    _ = try await second

    #expect(attestor.maximumConcurrentAssertions == 1)
    #expect(attestor.assertionCount == 2)
    #expect(transport.requests.filter { $0.url?.path == "/v1/countries.json" }.count == 2)
  }

  @Test func baseURLAndRequestScopeRejectUnsafeRoutes() async throws {
    #expect(throws: CountriesAPIClient.ClientError.self) {
      _ = try CountriesAPIClient(baseURL: URL(string: "http://api.example.test/v1")!)
    }

    let client = try CountriesAPIClient(baseURL: baseURL, attestor: FakeAttestor(isSupported: true))
    do {
      _ = try await client.request(path: "/countries.json", language: .en)
      Issue.record("Expected an absolute path outside the /v1 root to fail")
    } catch is CountriesAPIClient.ClientError {
      // Expected.
    }
    do {
      _ = try await client.request(path: "../countries.json", language: .en)
      Issue.record("Expected path traversal to fail")
    } catch is CountriesAPIClient.ClientError {
      // Expected.
    }
  }

  private func request(path: String) -> URLRequest {
    var request = URLRequest(url: URL(string: "https://api.example.test\(path)")!)
    request.httpMethod = "GET"
    request.httpBody = nil
    request.setValue("en", forHTTPHeaderField: "Accept-Language")
    return request
  }

  private func makeDefaults() -> UserDefaults {
    let suite = "CountriesAPIClientTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
  }

  private var noSleep: @Sendable (UInt64) async -> Void {
    { _ in }
  }
}

nonisolated private final class FakeAttestor: CountriesAppAttestService, @unchecked Sendable {
  let isSupported: Bool
  let assertionDelayNanoseconds: UInt64
  private let lock = NSLock()
  private var generatedKeys = 0
  private var attestations = 0
  private var assertions = 0
  private var activeAssertions = 0
  private var maxActiveAssertions = 0
  private var assertionHashes: [Data] = []

  init(isSupported: Bool, assertionDelayNanoseconds: UInt64 = 0) {
    self.isSupported = isSupported
    self.assertionDelayNanoseconds = assertionDelayNanoseconds
  }

  var generateKeyCount: Int { lock.withLock { generatedKeys } }
  var attestationCount: Int { lock.withLock { attestations } }
  var assertionCount: Int { lock.withLock { assertions } }
  var maximumConcurrentAssertions: Int { lock.withLock { maxActiveAssertions } }
  var hashes: [Data] { lock.withLock { assertionHashes } }

  func generateKey() async throws -> String {
    let number = lock.withLock { () -> Int in
      generatedKeys += 1
      return generatedKeys
    }
    return "key-\(number)"
  }

  func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
    lock.withLock {
      attestations += 1
    }
    return Data([0xA1, 0x01])
  }

  func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
    lock.withLock {
      assertions += 1
      activeAssertions += 1
      maxActiveAssertions = max(maxActiveAssertions, activeAssertions)
      assertionHashes.append(clientDataHash)
    }
    if assertionDelayNanoseconds > 0 {
      try? await Task.sleep(nanoseconds: assertionDelayNanoseconds)
    }
    lock.withLock {
      activeAssertions -= 1
    }
    return Data([0xB2, 0x02])
  }
}

nonisolated private final class RecordingCountriesTransport: CountriesAPITransport, @unchecked Sendable {
  enum Outcome {
    case response(status: Int, headers: [String: String], body: Data)
  }

  typealias Responder = (URLRequest, Int) throws -> Outcome

  private let lock = NSLock()
  private let responder: Responder
  private var storedRequests: [URLRequest] = []

  init(_ responder: @escaping Responder) {
    self.responder = responder
  }

  var requests: [URLRequest] { lock.withLock { storedRequests } }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let occurrence = lock.withLock { () -> Int in
      storedRequests.append(request)
      return storedRequests.count
    }
    let outcome = try responder(request, occurrence)
    guard case .response(let status, let headers, let body) = outcome,
      let url = request.url,
      let response = HTTPURLResponse(
        url: url,
        statusCode: status,
        httpVersion: "HTTP/1.1",
        headerFields: headers)
    else {
      throw URLError(.badServerResponse)
    }
    return (body, response)
  }
}

nonisolated private final class LockedValues<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var storedValues: [Value] = []

  nonisolated func append(_ value: Value) {
    lock.withLock {
      storedValues.append(value)
    }
  }

  nonisolated var values: [Value] {
    lock.withLock { storedValues }
  }
}

private func challengeBody(
  _ challenge: String,
  expiresAt: String = "2099-01-01T00:00:00.000Z"
) -> Data {
  Data(#"{"challenge":"\#(challenge)","expiresAt":"\#(expiresAt)"}"#.utf8)
}

private extension Data {
  var hexString: String {
    map { String(format: "%02x", $0) }.joined()
  }
}

private extension NSLock {
  nonisolated func withLock<T>(_ body: () throws -> T) rethrows -> T {
    lock()
    defer { unlock() }
    return try body()
  }
}
