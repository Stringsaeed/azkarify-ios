import CryptoKit
import DeviceCheck
import Foundation

/// The small boundary used by the location catalog.  Keeping the transport
/// injectable lets the catalog tests exercise authentication without making
/// network requests.
nonisolated protocol CountriesAPITransport: Sendable {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// The App Attest surface used by `CountriesAPIClient`.
///
/// `DCAppAttestService` is deliberately hidden behind this protocol so the
/// request protocol can be tested with deterministic keys and hashes.
nonisolated protocol CountriesAppAttestService: Sendable {
  var isSupported: Bool { get }

  func generateKey() async throws -> String
  func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data
  func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data
}

/// Production adapter for Apple's App Attest service.
nonisolated final class DCAppAttestServiceAdapter: CountriesAppAttestService, @unchecked Sendable {
  // DeviceCheck is imported as MainActor-isolated by the current SDK. The
  // adapter is the single concurrency boundary for Apple's thread-safe App
  // Attest service; CountriesAPIClient still serializes every call.
  nonisolated(unsafe) private let service: DCAppAttestService

  nonisolated init(service: DCAppAttestService = .shared) {
    self.service = service
  }

  nonisolated var isSupported: Bool { service.isSupported }

  nonisolated func generateKey() async throws -> String {
    try await service.generateKey()
  }

  nonisolated func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
    try await service.attestKey(keyID, clientDataHash: clientDataHash)
  }

  nonisolated func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
    try await service.generateAssertion(keyID, clientDataHash: clientDataHash)
  }
}

/// A URLSession transport with the network behavior required by the
/// authenticated catalog API.
nonisolated final class URLSessionCountriesAPITransport: CountriesAPITransport, @unchecked Sendable {
  private let session: URLSession
  private let delegate: RedirectBlockingURLSessionDelegate

  nonisolated init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.urlCredentialStorage = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

    let delegate = RedirectBlockingURLSessionDelegate()
    self.delegate = delegate
    self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
  }

  nonisolated func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else {
      throw CountriesAPIClient.ClientError.invalidHTTPResponse
    }
    return (data, response)
  }
}

private final class RedirectBlockingURLSessionDelegate: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    // The URL is part of the App Attest signature. A redirect would send a
    // different URL than the one that was signed, so fail the request.
    completionHandler(nil)
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    // Do not allow HTTP basic, client-certificate, or other credential
    // challenges. The system's normal server-trust handling remains enabled.
    if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
      completionHandler(.performDefaultHandling, nil)
    } else {
      completionHandler(.cancelAuthenticationChallenge, nil)
    }
  }
}

/// Authenticated App Attest transport for the Countries API.
///
/// Pass a `/v1` root, for example `https://api.saeed.sh/v1`. Authentication
/// endpoints are resolved relative to that root (`/v1/auth/...`), so the
/// client does not add a second `/v1` segment. The client never falls back to
/// an unauthenticated request.
actor CountriesAPIClient: CountriesAPITransport {
  enum Language: String, Sendable {
    case en
    case ar
  }

  enum ClientError: Swift.Error, LocalizedError {
    case unsupportedDevice
    case invalidBaseURL
    case invalidRequest
    case invalidHTTPResponse
    case malformedChallenge
    case pendingEnrollmentExpired
    case invalidAppAttestKey
    case appAttest(Swift.Error)
    case transport(Swift.Error)
    case httpStatus(Int, code: String?)

    var errorDescription: String? {
      switch self {
      case .unsupportedDevice:
        return "App Attest is not supported on this device."
      case .invalidBaseURL:
        return "The Countries API base URL must be an HTTPS /v1 URL."
      case .invalidRequest:
        return "The Countries API request must be a bodyless HTTPS GET on the configured origin."
      case .invalidHTTPResponse:
        return "The Countries API returned an invalid HTTP response."
      case .malformedChallenge:
        return "The Countries API returned an invalid challenge."
      case .pendingEnrollmentExpired:
        return "The pending App Attest enrollment expired before it could be confirmed."
      case .invalidAppAttestKey:
        return "The App Attest key is invalid and must be enrolled again."
      case .appAttest(let error):
        return "App Attest failed: \(error.localizedDescription)"
      case .transport(let error):
        return "The Countries API transport failed: \(error.localizedDescription)"
      case .httpStatus(let status, let code):
        if let code {
          return "The Countries API returned HTTP \(status) (\(code))."
        }
        return "The Countries API returned HTTP \(status)."
      }
    }
  }

  private struct ChallengeRequest: Encodable {
    let keyId: String
    let purpose: String
  }

  private struct ChallengeResponse: Decodable {
    let challenge: String
    let expiresAt: String
  }

  private struct PendingEnrollment: Codable {
    let keyID: String
    var challenge: String?
    var challengeExpiresAt: Date?
    var attestation: Data?
  }

  private struct Problem: Decodable {
    let code: String?
    let type: String?
    let title: String?
    let detail: String?
  }

  private let baseURL: URL
  // UserDefaults is imported as MainActor-isolated by the current SDK. The
  // client actor is the sole owner of this handle and serializes all access.
  nonisolated(unsafe) private let defaults: UserDefaults
  private let attestor: any CountriesAppAttestService
  private let transport: any CountriesAPITransport
  private let sleeper: @Sendable (UInt64) async -> Void
  private let enrolledKeyDefaultsKey: String
  private let pendingEnrollmentDefaultsKey: String
  private var tail: Task<Void, Never>?

  nonisolated private static let maximumTransientAttempts = 3
  nonisolated private static let backoffNanoseconds: [UInt64] = [250_000_000, 500_000_000]

  @preconcurrency init(
    baseURL: URL,
    environment: String? = nil,
    defaults: UserDefaults = .standard,
    attestor: any CountriesAppAttestService = DCAppAttestServiceAdapter(),
    transport: any CountriesAPITransport = URLSessionCountriesAPITransport(),
    sleeper: @escaping @Sendable (UInt64) async -> Void = { nanoseconds in
      try? await Task.sleep(nanoseconds: nanoseconds)
    }
  ) throws {
    guard let normalized = Self.normalizedBaseURL(baseURL) else {
      throw ClientError.invalidBaseURL
    }

    self.baseURL = normalized
    self.defaults = defaults
    self.attestor = attestor
    self.transport = transport
    self.sleeper = sleeper

    let environmentName = environment?.trimmingCharacters(in: .whitespacesAndNewlines)
    let namespaceInput = (environmentName?.isEmpty == false ? environmentName! + "|" : "")
      + normalized.absoluteString
    let namespace = Self.sha256Hex(namespaceInput)
    self.enrolledKeyDefaultsKey = "countries-api.app-attest.\(namespace).enrolled-key"
    self.pendingEnrollmentDefaultsKey = "countries-api.app-attest.\(namespace).pending-enrollment"
  }

  /// Builds a bodyless catalog GET relative to the configured `/v1` root.
  /// `path` may include an encoded query, for example
  /// `countries.json?limit=250`.
  func request(
    path: String,
    language: Language,
    ifNoneMatch: String? = nil
  ) throws -> URLRequest {
    guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("#"),
      !path.split(separator: "/").contains(".."),
      let url = URL(string: path, relativeTo: baseURL)?.absoluteURL,
      Self.isAllowedRequestURL(url, baseURL: baseURL)
    else {
      throw ClientError.invalidRequest
    }

    var request = URLRequest(
      url: url,
      cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutInterval: 30)
    request.httpMethod = "GET"
    request.httpBody = nil
    request.httpBodyStream = nil
    request.httpShouldHandleCookies = false
    request.setValue(language.rawValue, forHTTPHeaderField: "Accept-Language")
    if let ifNoneMatch {
      request.setValue(ifNoneMatch, forHTTPHeaderField: "If-None-Match")
    }
    return request
  }

  /// Clears local enrollment state. Use this only for an explicit recovery
  /// flow after an administrator has removed the device key on the server.
  func resetEnrollment() {
    defaults.removeObject(forKey: enrolledKeyDefaultsKey)
    defaults.removeObject(forKey: pendingEnrollmentDefaultsKey)
  }

  /// Sends an authenticated catalog request. Every enrollment, assertion, and
  /// HTTP request is serialized for this client so Apple's monotonic counter
  /// reaches the server in order.
  func data(for original: URLRequest) async throws -> (Data, HTTPURLResponse) {
    guard attestor.isSupported else {
      // This check intentionally happens before queueing or contacting either
      // authentication endpoint. There is no anonymous fallback.
      throw ClientError.unsupportedDevice
    }

    let previous = tail
    let task = Task { [weak self] () throws -> (Data, HTTPURLResponse) in
      await previous?.value
      guard let self else {
        throw ClientError.transport(TransportDeallocatedError())
      }
      return try await self.performQueued(original)
    }
    tail = Task { _ = await task.result }
    return try await task.value
  }

  /// Exposed as a pure helper for request-signature tests and for keeping the
  /// Swift client exactly aligned with `src/auth.ts` on the server.
  nonisolated static func canonicalAssertionPayload(for request: URLRequest, challenge: String) throws -> String {
    guard let url = request.url, request.httpMethod == "GET", request.httpBody == nil,
      request.httpBodyStream == nil
    else {
      throw ClientError.invalidRequest
    }
    return [
      "countries-api:v1",
      "GET",
      url.absoluteString,
      request.value(forHTTPHeaderField: "Accept-Language") ?? "",
      request.value(forHTTPHeaderField: "If-None-Match") ?? "",
      challenge,
    ].joined(separator: "\n")
  }

  nonisolated static func assertionClientDataHash(for request: URLRequest, challenge: String) throws -> Data {
    let payload = try canonicalAssertionPayload(for: request, challenge: challenge)
    return Data(SHA256.hash(data: Data(payload.utf8)))
  }

  private func performQueued(_ original: URLRequest) async throws -> (Data, HTTPURLResponse) {
    guard let url = original.url, Self.isAllowedRequestURL(url, baseURL: baseURL),
      original.httpMethod == "GET", original.httpBody == nil, original.httpBodyStream == nil
    else {
      throw ClientError.invalidRequest
    }

    var recoveryAttempted = false
    while true {
      do {
        let keyID = try await withTransientRetries {
          try await self.ensureEnrolledKey()
        }
        do {
          return try await performAuthenticatedRequest(original, keyID: keyID)
        } catch let error as ClientError {
          // The current server uses generic `unauthorized` for a missing
          // device record. Rotate only if a future server explicitly sends
          // `key_not_registered`; never rotate on any generic 401.
          if error.isExplicitlyUnregisteredKey, !recoveryAttempted {
            recoveryAttempted = true
            resetEnrollment()
            continue
          }
          throw error
        }
      } catch let error as ClientError {
        if (
          error.isExplicitlyUnregisteredKey
            || error.isInvalidAppAttestKey
            || error.isPendingEnrollmentExpired
        ), !recoveryAttempted {
          recoveryAttempted = true
          resetEnrollment()
          continue
        }
        throw error
      }
    }
  }

  private func ensureEnrolledKey() async throws -> String {
    guard attestor.isSupported else { throw ClientError.unsupportedDevice }

    if let enrolled = defaults.string(forKey: enrolledKeyDefaultsKey), !enrolled.isEmpty {
      // An enrolled key is authoritative. A stale pending record must not
      // cause Apple attestation to run again for that key.
      defaults.removeObject(forKey: pendingEnrollmentDefaultsKey)
      return enrolled
    }

    var pending = loadPendingEnrollment()
    if pending == nil {
      let keyID: String
      do {
        keyID = try await attestor.generateKey()
      } catch {
        throw mapAppAttestError(error)
      }
      pending = PendingEnrollment(
        keyID: keyID,
        challenge: nil,
        challengeExpiresAt: nil,
        attestation: nil)
      savePendingEnrollment(pending!)
    }

    guard var enrollment = pending, !enrollment.keyID.isEmpty else {
      throw ClientError.malformedChallenge
    }

    if let attestation = enrollment.attestation {
      guard let challenge = enrollment.challenge else {
        // Never call Apple's attestation API again when we have already
        // persisted a successful attestation object without its challenge.
        throw ClientError.malformedChallenge
      }
      if let expiresAt = enrollment.challengeExpiresAt, expiresAt <= Date() {
        // A lost 204 can leave a valid server registration behind after this
        // challenge expires. Probe first so an offline restart never rotates
        // a key that the server already accepted. A transport error leaves
        // this pending object intact for a later retry.
        if try await serverRecognizesKey(keyID: enrollment.keyID) {
          finalizeEnrollment(keyID: enrollment.keyID)
          return enrollment.keyID
        }

        // The App Attest object is bound to this expired challenge and cannot
        // be regenerated safely with a new challenge. The outer queued
        // recovery path clears it once and creates a replacement key.
        throw ClientError.pendingEnrollmentExpired
      }

      return try await confirmEnrollment(
        keyID: enrollment.keyID,
        challenge: challenge,
        attestation: attestation)
    }

    if let expiresAt = enrollment.challengeExpiresAt, expiresAt <= Date() {
      enrollment.challenge = nil
      enrollment.challengeExpiresAt = nil
      savePendingEnrollment(enrollment)
    }

    if enrollment.challenge == nil {
      let issued = try await issueChallenge(keyID: enrollment.keyID, purpose: "attestation")
      enrollment.challenge = issued.challenge
      enrollment.challengeExpiresAt = issued.expiresAt
      savePendingEnrollment(enrollment)
    }

    guard let challenge = enrollment.challenge else {
      throw ClientError.malformedChallenge
    }

    do {
      let hash = Data(SHA256.hash(data: Data(challenge.utf8)))
      // Save the returned App Attest object before making the HTTP request.
      // If the response is lost, the same object/challenge can be retried;
      // calling attestKey again for a successfully-attested key is unsafe.
      let attestation = try await attestor.attestKey(enrollment.keyID, clientDataHash: hash)
      enrollment.attestation = attestation
      savePendingEnrollment(enrollment)
    } catch {
      throw mapAppAttestError(error)
    }

    guard let attestation = enrollment.attestation else {
      throw ClientError.malformedChallenge
    }
    return try await confirmEnrollment(
      keyID: enrollment.keyID,
      challenge: challenge,
      attestation: attestation)
  }

  private func confirmEnrollment(
    keyID: String,
    challenge: String,
    attestation: Data
  ) async throws -> String {
    do {
      try await submitAttestation(keyID: keyID, challenge: challenge, attestation: attestation)
    } catch let error as ClientError {
      // The server consumes an attestation challenge on every verification
      // attempt. If a successful 204 was lost and a retry receives 401, a
      // fresh assertion challenge is the only safe way to learn whether the
      // key was actually registered. It does not consume Apple's counter.
      if case .httpStatus(401, _) = error {
        if try await serverRecognizesKey(keyID: keyID) {
          finalizeEnrollment(keyID: keyID)
          return keyID
        }
      }
      throw error
    }
    finalizeEnrollment(keyID: keyID)
    return keyID
  }

  private func serverRecognizesKey(keyID: String) async throws -> Bool {
    do {
      _ = try await issueChallenge(keyID: keyID, purpose: "assertion")
      return true
    } catch let error as ClientError {
      if case .httpStatus(401, _) = error {
        return false
      }
      throw error
    }
  }

  private func performAuthenticatedRequest(
    _ original: URLRequest,
    keyID: String
  ) async throws -> (Data, HTTPURLResponse) {
    var unauthorizedRetryUsed = false

    while true {
      do {
        let result = try await withTransientRetries {
          try await self.sendAuthenticatedAttempt(original, keyID: keyID)
        }
        return result
      } catch let error as ClientError {
        if case .httpStatus(401, _) = error, !unauthorizedRetryUsed {
          // A challenge is single-use. Rebuild the complete assertion with a
          // fresh challenge; the original assertion must never be replayed.
          unauthorizedRetryUsed = true
          continue
        }
        throw error
      }
    }
  }

  private func sendAuthenticatedAttempt(
    _ original: URLRequest,
    keyID: String
  ) async throws -> (Data, HTTPURLResponse) {
    let issued = try await issueChallenge(keyID: keyID, purpose: "assertion")
    var request = original
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.httpShouldHandleCookies = false

    let hash: Data
    do {
      hash = try Self.assertionClientDataHash(for: request, challenge: issued.challenge)
    } catch let error as ClientError {
      throw error
    } catch {
      throw ClientError.invalidRequest
    }

    let assertion: Data
    do {
      assertion = try await attestor.generateAssertion(keyID, clientDataHash: hash)
    } catch {
      throw mapAppAttestError(error)
    }

    request.setValue(keyID, forHTTPHeaderField: "X-App-Attest-Key-Id")
    request.setValue(issued.challenge, forHTTPHeaderField: "X-App-Attest-Challenge")
    request.setValue(assertion.base64EncodedString(), forHTTPHeaderField: "X-App-Attest-Assertion")

    let (data, response) = try await callTransport(request)
    guard Self.isAcceptedDataStatus(response.statusCode) else {
      throw makeHTTPError(response: response, data: data)
    }
    return (data, response)
  }

  private func issueChallenge(keyID: String, purpose: String) async throws -> (challenge: String, expiresAt: Date) {
    let url = baseURL.appendingPathComponent("auth").appendingPathComponent("challenge")
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
    request.httpMethod = "POST"
    request.httpShouldHandleCookies = false
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(ChallengeRequest(keyId: keyID, purpose: purpose))

    let (data, response) = try await callTransport(request)
    guard response.statusCode == 200 else {
      throw makeHTTPError(response: response, data: data)
    }
    guard let challengeResponse = try? JSONDecoder().decode(ChallengeResponse.self, from: data),
      !challengeResponse.challenge.isEmpty
    else {
      throw ClientError.malformedChallenge
    }

    guard let expiresAt = Self.parseISO8601(challengeResponse.expiresAt) else {
      throw ClientError.malformedChallenge
    }
    return (challengeResponse.challenge, expiresAt)
  }

  private func submitAttestation(keyID: String, challenge: String, attestation: Data) async throws {
    let url = baseURL.appendingPathComponent("auth").appendingPathComponent("attest")
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
    request.httpMethod = "POST"
    request.httpShouldHandleCookies = false
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode([
      "keyId": keyID,
      "challenge": challenge,
      "attestation": attestation.base64EncodedString(),
    ])

    let (data, response) = try await callTransport(request)
    guard response.statusCode == 204 else {
      // Enrollment is complete only after the documented 204. Keep the
      // pending object persisted for a retry if the server did not confirm it.
      throw makeHTTPError(response: response, data: data)
    }
  }

  private func callTransport(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    do {
      return try await transport.data(for: request)
    } catch let error as ClientError {
      throw error
    } catch {
      throw ClientError.transport(error)
    }
  }

  private func withTransientRetries<T>(
    _ operation: () async throws -> T
  ) async throws -> T {
    var attempt = 0
    while true {
      do {
        return try await operation()
      } catch {
        guard Self.isTransient(error), attempt < Self.maximumTransientAttempts - 1 else {
          throw error
        }
        await sleeper(Self.backoffNanoseconds[attempt])
        attempt += 1
      }
    }
  }

  private func mapAppAttestError(_ error: Swift.Error) -> ClientError {
    let nsError = error as NSError
    if nsError.domain == DCError.errorDomain && nsError.code == DCError.invalidKey.rawValue {
      return .invalidAppAttestKey
    }
    return .appAttest(error)
  }

  private func makeHTTPError(response: HTTPURLResponse, data: Data) -> ClientError {
    let problem = try? JSONDecoder().decode(Problem.self, from: data)
    let code = problem?.title
      ?? problem?.code
      ?? problem?.type?.split(separator: "/").last.map(String.init)
    return .httpStatus(response.statusCode, code: code)
  }

  nonisolated private static func parseISO8601(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) {
      return date
    }

    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    return standard.date(from: value)
  }

  private func loadPendingEnrollment() -> PendingEnrollment? {
    guard let data = defaults.data(forKey: pendingEnrollmentDefaultsKey) else { return nil }
    return try? JSONDecoder().decode(PendingEnrollment.self, from: data)
  }

  private func savePendingEnrollment(_ enrollment: PendingEnrollment) {
    guard let data = try? JSONEncoder().encode(enrollment) else { return }
    defaults.set(data, forKey: pendingEnrollmentDefaultsKey)
  }

  private func finalizeEnrollment(keyID: String) {
    // Persist the key only after the server returned 204. Apple keeps the
    // private key; this ID is only the environment-scoped lookup handle.
    defaults.set(keyID, forKey: enrolledKeyDefaultsKey)
    defaults.removeObject(forKey: pendingEnrollmentDefaultsKey)
  }

  nonisolated private static func normalizedBaseURL(_ url: URL) -> URL? {
    guard url.scheme?.lowercased() == "https", url.host != nil,
      url.user == nil, url.password == nil, url.fragment == nil,
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      components.query == nil
    else {
      return nil
    }

    var normalized = components
    let path = normalized.path.isEmpty ? "/" : normalized.path
    guard path.split(separator: "/").last == "v1" else {
      return nil
    }
    normalized.path = path.hasSuffix("/") ? path : path + "/"
    return normalized.url
  }

  nonisolated private static func isAllowedRequestURL(_ url: URL, baseURL: URL) -> Bool {
    guard url.scheme?.lowercased() == "https", url.host?.lowercased() == baseURL.host?.lowercased(),
      effectivePort(url) == effectivePort(baseURL), url.user == nil, url.password == nil,
      url.fragment == nil
    else {
      return false
    }

    let basePath = normalizedPath(baseURL.path)
    let requestPath = normalizedPath(url.path)
    return requestPath == basePath || requestPath.hasPrefix(basePath + "/")
  }

  nonisolated private static func normalizedPath(_ path: String) -> String {
    let value = path.isEmpty ? "/" : path
    if value == "/" { return "" }
    return value.hasSuffix("/") ? String(value.dropLast()) : value
  }

  nonisolated private static func effectivePort(_ url: URL) -> Int {
    url.port ?? 443
  }

  nonisolated private static func isAcceptedDataStatus(_ status: Int) -> Bool {
    (200..<300).contains(status) || status == 304
  }

  nonisolated private static func isTransient(_ error: Swift.Error) -> Bool {
    if let error = error as? ClientError {
      switch error {
      case .transport(let underlying):
        if let urlError = underlying as? URLError {
          return transientURLCodes.contains(urlError.code)
        }
        return false
      case .httpStatus(let status, _):
        return [408, 425, 500, 502, 503, 504].contains(status)
      case .appAttest(let underlying):
        let nsError = underlying as NSError
        return nsError.domain == DCError.errorDomain
          && nsError.code == DCError.serverUnavailable.rawValue
      default:
        return false
      }
    }
    if let urlError = error as? URLError {
      return transientURLCodes.contains(urlError.code)
    }
    return false
  }

  nonisolated private static let transientURLCodes: Set<URLError.Code> = [
    .badServerResponse,
    .cannotConnectToHost,
    .cannotFindHost,
    .dnsLookupFailed,
    .networkConnectionLost,
    .notConnectedToInternet,
    .resourceUnavailable,
    .timedOut,
  ]

  nonisolated private static func sha256Hex(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }
}

private struct TransportDeallocatedError: Swift.Error, LocalizedError {
  var errorDescription: String? { "The Countries API client was deallocated." }
}

private extension CountriesAPIClient.ClientError {
  var isExplicitlyUnregisteredKey: Bool {
    if case .httpStatus(401, let code) = self {
      return code == "key_not_registered"
    }
    return false
  }

  var isInvalidAppAttestKey: Bool {
    if case .invalidAppAttestKey = self {
      return true
    }
    return false
  }

  var isPendingEnrollmentExpired: Bool {
    if case .pendingEnrollmentExpired = self {
      return true
    }
    return false
  }
}
