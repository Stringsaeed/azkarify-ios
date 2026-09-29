import SwiftData
import SwiftUI
import UserNotifications

@main
struct azkarifyApp: App {
  private let container: ModelContainer
  @StateObject private var store: AzkarStore
  @AppStorage("theme") private var theme = "system"
  @AppStorage("accent") private var accent = "brown"
  @AppStorage("font") private var selectedFont = "ibmPlexSansArabic"
  @AppStorage("hasSeenIntro") private var hasSeenIntro = false

  init() {
    AppAppearance.registerFonts()
    _ = RevenueCatService.isConfigured
    UNUserNotificationCenter.current().delegate = ReminderScheduler.delegate
    do {
      let container = try ModelContainer(for: CachedAzkarDocument.self)
      self.container = container
      _store = StateObject(
        wrappedValue: AzkarStore(repository: AzkarRepository(context: container.mainContext)))
    } catch {
      fatalError("Could not open the azkar cache: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(store)
        .modelContainer(container)
        .preferredColorScheme(theme == "dark" ? .dark : theme == "light" ? .light : nil)
        .tint(AppAppearance.accent(accent))
        .font(AppAppearance.font(language: store.language, choice: selectedFont, size: 17))
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
