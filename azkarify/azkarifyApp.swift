import SwiftUI
import UserNotifications

@main
struct azkarifyApp: App {
  @StateObject private var store: AzkarStore
  @AppStorage("theme") private var theme = "system"
  @AppStorage("accent") private var accent = "brown"
  @AppStorage("hasSeenIntro") private var hasSeenIntro = false

  init() {
    AppAppearance.registerFonts()
    _ = RevenueCatService.isConfigured
    UNUserNotificationCenter.current().delegate = ReminderScheduler.delegate
    _store = StateObject(wrappedValue: AzkarStore(repository: AzkarRepository()))
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(store)
        .preferredColorScheme(theme == "dark" ? .dark : theme == "light" ? .light : nil)
        .tint(AppAppearance.accent(accent))
        .font(AppAppearance.font(size: 17))
        .fullScreenCover(
          isPresented: Binding(
            get: { !hasSeenIntro },
            set: { if !$0 { hasSeenIntro = true } }
          )
        ) {
          IntroView { hasSeenIntro = true }
            .environmentObject(store)
            .tint(AppAppearance.accent(accent))
        }
    }
  }
}
