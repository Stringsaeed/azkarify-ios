import SwiftUI

struct ReminderSettingView: View {
  let kind: ReminderKind
  let language: String
  @State private var enabled: Bool
  @State private var time: Date
  @State private var isSaving = false
  @State private var errorMessage: String?

  init(kind: ReminderKind, language: String) {
    self.kind = kind
    self.language = language
    _enabled = State(initialValue: UserDefaults.standard.bool(forKey: kind.enabledKey))
    _time = State(initialValue: kind.savedTime())
  }

  var body: some View {
    Toggle(
      isOn: Binding(
        get: { enabled },
        set: { newValue in Task { await update(enabled: newValue, time: time) } }
      )
    ) {
      VStack(alignment: .leading, spacing: 2) {
        Text(rowTitle).azText(.rowTitle)
        if enabled {
          Text(AZLocale.text("Every day at \(time.formatted(date: .omitted, time: .shortened))",
                             "كل يوم الساعة \(time.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(AZLocale.locale)))"))
            .azText(.footnote)
            .foregroundStyle(AZColor.inkMuted)
        }
      }
    }
    .tint(AZColor.forest)
    .disabled(isSaving)
    .task(id: language) {
      if enabled {
        try? await ReminderScheduler.set(kind, enabled: true, at: time, language: language)
      }
    }
    .alert(
      AppCopy.text("Reminder unavailable"),
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )
    ) {
      Button(AppCopy.text("OK")) { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "")
    }

    if enabled {
      DatePicker(
        AZLocale.text("Time", "الوقت"),
        selection: Binding(
          get: { time },
          set: { newValue in Task { await update(enabled: true, time: newValue) } }
        ),
        displayedComponents: .hourAndMinute
      )
      .disabled(isSaving)
    }
  }

  private var rowTitle: String {
    switch kind {
    case .morning: AZLocale.text("Morning azkar", "أذكار الصباح")
    case .evening: AZLocale.text("Evening azkar", "أذكار المساء")
    }
  }

  private func update(enabled newEnabled: Bool, time newTime: Date) async {
    isSaving = true
    defer { isSaving = false }
    do {
      try await ReminderScheduler.set(kind, enabled: newEnabled, at: newTime, language: language)
      enabled = newEnabled
      time = newTime
      let defaults = UserDefaults.standard
      defaults.set(newEnabled, forKey: kind.enabledKey)
      let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)
      defaults.set(components.hour, forKey: kind.hourKey)
      defaults.set(components.minute, forKey: kind.minuteKey)
    } catch {
      errorMessage =
        error is ReminderError
        ? AppCopy.text("Enable notifications for Azkarify in iOS Settings.")
        : error.localizedDescription
    }
  }
}
