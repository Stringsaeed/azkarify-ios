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
      kind.title(language: language),
      isOn: Binding(
        get: { enabled },
        set: { newValue in Task { await update(enabled: newValue, time: time) } }
      )
    )
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
        kind.title(language: language),
        selection: Binding(
          get: { time },
          set: { newValue in Task { await update(enabled: true, time: newValue) } }
        ),
        displayedComponents: .hourAndMinute
      )
      .disabled(isSaving)
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
