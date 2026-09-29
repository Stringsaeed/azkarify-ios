import Foundation
import UserNotifications

enum ReminderKind: String {
  case morning
  case evening

  var hour: Int { self == .morning ? 8 : 18 }
  var identifier: String { "azkarify.\(rawValue)" }
  var enabledKey: String { "reminder.\(rawValue).enabled" }
  var hourKey: String { "reminder.\(rawValue).hour" }
  var minuteKey: String { "reminder.\(rawValue).minute" }

  func savedTime() -> Date {
    let defaults = UserDefaults.standard
    let hour =
      defaults.object(forKey: hourKey) == nil ? self.hour : defaults.integer(forKey: hourKey)
    let minute = defaults.integer(forKey: minuteKey)
    return Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
  }

  func title(language: String) -> String {
    switch self {
    case .morning: AppCopy.text("🌅 Morning reminder")
    case .evening: AppCopy.text("🌙 Evening reminder")
    }
  }

  func body(language: String) -> String {
    switch self {
    case .morning:
      AppCopy.text("Time for morning azkar")
    case .evening:
      AppCopy.text("Time for evening azkar")
    }
  }
}

enum ReminderError: LocalizedError {
  case permissionDenied

  var errorDescription: String? {
    switch self {
    case .permissionDenied:
      AppCopy.text("Notifications are disabled. Enable them in iOS Settings to use reminders.")
    }
  }
}

@MainActor
enum ReminderScheduler {
  static let delegate = ReminderNotificationDelegate()

  static func set(_ kind: ReminderKind, enabled: Bool, at time: Date, language: String) async throws
  {
    let center = UNUserNotificationCenter.current()
    if enabled {
      let status = await center.notificationSettings().authorizationStatus
      let allowed: Bool
      if status == .notDetermined {
        allowed = try await center.requestAuthorization(options: [.alert, .sound])
      } else {
        allowed = status == .authorized || status == .provisional || status == .ephemeral
      }
      guard allowed else { throw ReminderError.permissionDenied }

      let content = UNMutableNotificationContent()
      content.title = kind.title(language: language)
      content.body = kind.body(language: language)
      content.sound = .default
      let components = Calendar.current.dateComponents([.hour, .minute], from: time)
      let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
      try await center.add(
        UNNotificationRequest(identifier: kind.identifier, content: content, trigger: trigger))
    } else {
      center.removePendingNotificationRequests(withIdentifiers: [kind.identifier])
    }
  }
}

final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }
}
