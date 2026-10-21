import SwiftUI
import UserNotifications

@main
struct azkarifyApp: App {
  @StateObject private var store: AzkarStore
  @StateObject private var journeyProgress = JourneyProgressStore()
  @StateObject private var locationCatalog = LocationCatalogStore()
  @StateObject private var prayerSchedule = PrayerScheduleStore()
  @AppStorage("theme") private var theme = "system"
  @AppStorage("accent") private var accent = "brown"
  @AppStorage("hasSeenIntro") private var hasSeenIntro = false
  @State private var canPresentLocationSetup = false

  init() {
    AZFont.registerFonts()
    AZAppearance.configureUIKit()
    _ = RevenueCatService.isConfigured
    UNUserNotificationCenter.current().delegate = ReminderScheduler.delegate
    _store = StateObject(wrappedValue: AzkarStore(repository: AzkarRepository()))
  }

  var body: some Scene {
    WindowGroup {
      ContentView(canPresentLocationSetup: canPresentLocationSetup)
        .environmentObject(store)
        .environmentObject(prayerSchedule)
        .environmentObject(journeyProgress)
        .environmentObject(locationCatalog)
        .preferredColorScheme(theme == "dark" ? .dark : theme == "light" ? .light : nil)
        .tint(AZAccent.color(accent))
        .font(AZFont.font(.body))
        .foregroundStyle(AZColor.ink)
        .environment(\.layoutDirection, AZLocale.isArabic ? .rightToLeft : .leftToRight)
        .onAppear { canPresentLocationSetup = hasSeenIntro }
        .fullScreenCover(
          isPresented: Binding(
            get: { !hasSeenIntro },
            set: { if !$0 { hasSeenIntro = true } }
          ),
          onDismiss: { canPresentLocationSetup = true }
        ) {
          IntroView { hasSeenIntro = true }
            .environmentObject(store)
            .tint(AZAccent.color(accent))
        }
    }
  }
}
