import SwiftUI
import UIKit

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

private enum AppTab: Hashable, CaseIterable {
  case today, azkar, counter, settings

  /// Stable identifiers for UI tests and automation, in tab order.
  var accessibilityIdentifier: String {
    switch self {
    case .today: "tab.today"
    case .azkar: "tab.azkar"
    case .counter: "tab.counter"
    case .settings: "tab.settings"
    }
  }
}

/// `Tab.accessibilityIdentifier` reaches the tab bar only after a later SwiftUI update, so a
/// fresh launch can show unlabelled tabs. This sets the identifiers on the bar's items directly.
private struct TabBarIdentifiers: UIViewControllerRepresentable {
  let identifiers: [String]

  func makeUIViewController(context: Context) -> Controller { Controller(identifiers: identifiers) }

  func updateUIViewController(_ controller: Controller, context: Context) {
    controller.identifiers = identifiers
    controller.apply()
  }

  final class Controller: UIViewController {
    var identifiers: [String]

    init(identifiers: [String]) {
      self.identifiers = identifiers
      super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
      super.viewDidLoad()
      view.isUserInteractionEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      apply()
      // The bar's items can arrive after this view appears.
      DispatchQueue.main.async { [weak self] in self?.apply() }
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      apply()
    }

    func apply() {
      guard let root = view.window?.rootViewController ?? parent,
        let tabBar = Self.tabBarController(in: root)?.tabBar
      else { return }
      for (item, identifier) in zip(tabBar.items ?? [], identifiers)
      where item.accessibilityIdentifier != identifier {
        item.accessibilityIdentifier = identifier
      }
    }

    private static func tabBarController(in controller: UIViewController) -> UITabBarController? {
      if let tabs = controller as? UITabBarController { return tabs }
      for child in controller.children {
        if let tabs = tabBarController(in: child) { return tabs }
      }
      return controller.presentedViewController.flatMap { tabBarController(in: $0) }
    }
  }
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
      .accessibilityIdentifier(AppTab.today.accessibilityIdentifier)
      Tab(AZLocale.text("Azkar", "الأذكار"), systemImage: "book", value: AppTab.azkar) {
        AzkarTab()
      }
      .accessibilityIdentifier(AppTab.azkar.accessibilityIdentifier)
      Tab(AZLocale.text("Counter", "السبحة"), systemImage: "circle.circle", value: AppTab.counter) {
        CounterTab()
      }
      .accessibilityIdentifier(AppTab.counter.accessibilityIdentifier)
      Tab(AZLocale.text("Settings", "الإعدادات"), systemImage: "gearshape", value: AppTab.settings) {
        NavigationStack {
          SettingsView(onChooseLocation: { showLocationSetup = true })
            .navigationDestination(for: DetailRoute.self) { $0.destination }
        }
      }
      .accessibilityIdentifier(AppTab.settings.accessibilityIdentifier)
    }
    .tabViewStyle(.sidebarAdaptable)
    .background {
      TabBarIdentifiers(identifiers: AppTab.allCases.map(\.accessibilityIdentifier))
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
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
