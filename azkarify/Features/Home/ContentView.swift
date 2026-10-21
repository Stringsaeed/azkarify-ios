import SwiftUI

/// Screens pushed inside a tab's navigation stack.
enum DetailRoute: Hashable {
  case journey(JourneyDefinition)
  case category(ZikrCategory)
  case prayerSettings

  var destination: some View { DetailRouteView(route: self) }
}

private struct DetailRouteView: View {
  @EnvironmentObject private var journeyProgress: JourneyProgressStore
  let route: DetailRoute

  var body: some View {
    switch route {
    case .journey(let journey): JourneyDetailView(journey: journey, progress: journeyProgress)
    case .category(let category): ZikrListView(category: category)
    case .prayerSettings: PrayerScheduleSettingsView()
    }
  }
}

private enum AppTab: Hashable {
  case today, azkar, counter, settings
}

/// The app's front door: four native tabs (a sidebar on iPad).
struct ContentView: View {
  var canPresentLocationSetup = false
  @EnvironmentObject private var store: AzkarStore
  @EnvironmentObject private var prayerSchedule: PrayerScheduleStore
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage("hasPresentedPrayerLocationSetup") private var hasPresentedLocationSetup = false
  @SceneStorage("selectedTab") private var storedTab = "today"
  @State private var showLocationSetup = false

  private var selectedTab: Binding<AppTab> {
    Binding(
      get: {
        switch storedTab {
        case "azkar": .azkar
        case "counter": .counter
        case "settings": .settings
        default: .today
        }
      },
      set: { tab in
        storedTab = switch tab {
        case .today: "today"
        case .azkar: "azkar"
        case .counter: "counter"
        case .settings: "settings"
        }
      })
  }

  var body: some View {
    TabView(selection: selectedTab) {
      Tab(AZLocale.text("Today", "اليوم"), systemImage: "sun.horizon", value: AppTab.today) {
        NavigationStack {
          TodayView(onChooseLocation: { showLocationSetup = true })
            .navigationDestination(for: DetailRoute.self) { $0.destination }
        }
      }
      .accessibilityIdentifier("tab.today")
      Tab(AZLocale.text("Azkar", "الأذكار"), systemImage: "book", value: AppTab.azkar) {
        AzkarTab()
      }
      .accessibilityIdentifier("tab.azkar")
      Tab(AZLocale.text("Counter", "السبحة"), systemImage: "circle.circle", value: AppTab.counter) {
        CounterTab()
      }
      .accessibilityIdentifier("tab.counter")
      Tab(AZLocale.text("Settings", "الإعدادات"), systemImage: "gearshape", value: AppTab.settings) {
        NavigationStack {
          SettingsView(onChooseLocation: { showLocationSetup = true })
            .navigationDestination(for: DetailRoute.self) { $0.destination }
        }
      }
      .accessibilityIdentifier("tab.settings")
    }
    .tabViewStyle(.sidebarAdaptable)
    .task(id: store.language) { await store.load() }
    .task(id: canPresentLocationSetup) { presentLocationSetupIfNeeded() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { presentLocationSetupIfNeeded() }
    }
    .sheet(isPresented: $showLocationSetup) {
      PrayerLocationSheet(onFinish: { showLocationSetup = false })
        .presentationDragIndicator(.visible)
        .onAppear { hasPresentedLocationSetup = true }
    }
  }

  private func presentLocationSetupIfNeeded() {
    guard canPresentLocationSetup, scenePhase == .active,
      !hasPresentedLocationSetup, prayerSchedule.configuration == nil else { return }
    showLocationSetup = true
  }
}
