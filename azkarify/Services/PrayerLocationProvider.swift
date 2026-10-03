import Combine
import CoreLocation
import Foundation

@MainActor
final class PrayerLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
  enum State: Equatable {
    case idle
    case requesting
    case located(latitude: Double, longitude: Double)
    case unavailable
  }

  @Published private(set) var state: State = .idle

  private let locationManager: CLLocationManager
  private var timeoutTask: Task<Void, Never>?
  private var requestID = 0
  private var hasRequestedLocation = false

  private static let requestTimeout: Duration = .seconds(15)
  private static let maximumLocationAge: TimeInterval = 5 * 60
  // Reduced-accuracy locations are useful for prayer times. A reading wider than
  // 100 km is too coarse to be a meaningful local location.
  private static let maximumHorizontalAccuracy: CLLocationAccuracy = 100_000

  init(locationManager: CLLocationManager = CLLocationManager()) {
    self.locationManager = locationManager
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    locationManager.distanceFilter = kCLDistanceFilterNone
  }

  deinit {
    timeoutTask?.cancel()
    locationManager.stopUpdatingLocation()
  }

  func requestLocation() {
    timeoutTask?.cancel()
    timeoutTask = nil
    requestID += 1
    hasRequestedLocation = false

    guard CLLocationManager.locationServicesEnabled() else {
      state = .unavailable
      return
    }

    state = .requesting

    switch locationManager.authorizationStatus {
    case .notDetermined:
      locationManager.requestWhenInUseAuthorization()
    case .authorizedAlways, .authorizedWhenInUse:
      requestOneLocation()
    case .denied, .restricted:
      finish(with: .unavailable)
    @unknown default:
      finish(with: .unavailable)
    }
  }

  func cancel() {
    requestID += 1
    hasRequestedLocation = false
    timeoutTask?.cancel()
    timeoutTask = nil
    locationManager.stopUpdatingLocation()
    state = .idle
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard state == .requesting else { return }
    guard CLLocationManager.locationServicesEnabled() else {
      finish(with: .unavailable)
      return
    }

    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      requestOneLocation()
    case .denied, .restricted:
      finish(with: .unavailable)
    case .notDetermined:
      break
    @unknown default:
      finish(with: .unavailable)
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard state == .requesting, hasRequestedLocation else { return }
    guard CLLocationManager.locationServicesEnabled() else {
      finish(with: .unavailable)
      return
    }

    let now = Date()
    guard let location = locations
      .filter({ Self.isUsableLocation($0, now: now) })
      .min(by: Self.locationQualityOrder)
    else { return }

    finish(with: .located(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard state == .requesting else { return }
    if let error = error as? CLError, error.code == .locationUnknown {
      // Core Location reports this while it is still trying to obtain a fix.
      // Keep the request alive until the timeout handles a missing fix.
      return
    }
    finish(with: .unavailable)
  }

  static func localConfiguration(
    latitude: Double,
    longitude: Double,
    language: String,
    timeZone: TimeZone = .current
  ) -> PrayerScheduleConfiguration {
    PrayerScheduleConfiguration(
      locationName: language.hasPrefix("ar") ? "الموقع الحالي" : "Current location",
      latitude: latitude,
      longitude: longitude,
      timeZoneIdentifier: timeZone.identifier,
      method: calculationMethod(for: timeZone.identifier),
      madhab: .shafi,
      usesDeviceLocation: true)
  }

  static func isUsableLocation(_ location: CLLocation, now: Date = Date()) -> Bool {
    let coordinate = location.coordinate
    guard CLLocationCoordinate2DIsValid(coordinate),
      coordinate.latitude.isFinite,
      coordinate.longitude.isFinite,
      location.horizontalAccuracy.isFinite,
      location.horizontalAccuracy >= 0,
      location.horizontalAccuracy <= maximumHorizontalAccuracy,
      location.timestamp.timeIntervalSince1970.isFinite
    else { return false }

    let age = now.timeIntervalSince(location.timestamp)
    return age >= -60 && age <= maximumLocationAge
  }

  private static func locationQualityOrder(_ lhs: CLLocation, _ rhs: CLLocation) -> Bool {
    if lhs.horizontalAccuracy == rhs.horizontalAccuracy {
      return lhs.timestamp > rhs.timestamp
    }
    return lhs.horizontalAccuracy < rhs.horizontalAccuracy
  }

  private static func calculationMethod(for timeZoneIdentifier: String) -> PrayerCalculationMethod {
    switch timeZoneIdentifier {
    case "Asia/Dubai":
      return .dubai
    case "Africa/Cairo":
      return .egyptian
    case "Asia/Riyadh":
      return .ummAlQura
    case "Asia/Kuwait":
      return .kuwait
    case "Asia/Qatar":
      return .qatar
    case "Asia/Singapore":
      return .singapore
    case "Asia/Karachi":
      return .karachi
    case "Asia/Tehran":
      return .tehran
    case "Europe/Istanbul":
      return .turkey
    case "Europe/London", "America/New_York":
      return .moonsightingCommittee
    case "America/Chicago", "America/Denver", "America/Los_Angeles", "America/Toronto":
      return .northAmerica
    default:
      return .muslimWorldLeague
    }
  }

  private func requestOneLocation() {
    guard state == .requesting, !hasRequestedLocation else { return }
    hasRequestedLocation = true
    startTimeout(for: requestID)
    locationManager.requestLocation()
  }

  private func startTimeout(for id: Int) {
    timeoutTask = Task { @MainActor [weak self] in
      do {
        try await Task.sleep(for: Self.requestTimeout)
      } catch {
        return
      }
      guard let self, self.requestID == id, self.state == .requesting else { return }
      self.finish(with: .unavailable)
    }
  }

  private func finish(with newState: State) {
    timeoutTask?.cancel()
    timeoutTask = nil
    hasRequestedLocation = false
    locationManager.stopUpdatingLocation()
    state = newState
  }
}
