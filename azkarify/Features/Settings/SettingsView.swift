import RevenueCat
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var store: AzkarStore
  @AppStorage("theme") private var theme = "system"
  @AppStorage("accent") private var accent = "brown"
  @State private var supportOffer: SupportOffer?
  @State private var isLoadingSupport = false
  @State private var paywallError: String?
  @State private var showIntro = false
  @State private var showAccentPicker = false

  var body: some View {
    Form {
      Picker(AppCopy.text("Theme"), selection: $theme) {
        Text(AppCopy.text("System")).tag("system")
        Text(AppCopy.text("Light")).tag("light")
        Text(AppCopy.text("Dark")).tag("dark")
      }
      if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
        Link(AppCopy.text("Language"), destination: settingsURL)
      }
      Button {
        showAccentPicker = true
      } label: {
        HStack {
          Text(AppCopy.text("Accent color"))
          Spacer()
          Circle()
            .fill(AppAppearance.accent(accent))
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
        }
      }
      Section(AppCopy.text("Reminders")) {
        ReminderSettingView(kind: .morning, language: store.language)
        ReminderSettingView(kind: .evening, language: store.language)
      }
      Section(store.language == "ar" ? "الرحلات اليومية" : "Daily journeys") {
        NavigationLink(value: DetailRoute.prayerSettings) {
          Label(store.language == "ar" ? "مواقيت الصلاة" : "Prayer times", systemImage: "sun.horizon")
        }
      }
      Button(AppCopy.text("View introduction")) {
        showIntro = true
      }
      Button {
        Task { await openPaywall() }
      } label: {
        HStack {
          Text(AppCopy.text("Support the developer"))
          if isLoadingSupport {
            Spacer()
            ProgressView()
          }
        }
      }
      .disabled(!RevenueCatService.isConfigured || isLoadingSupport)
    }
    .scrollContentBackground(.hidden)
    .background(AppAppearance.background(accent))
    .font(AppAppearance.font(size: 17))
    .tint(AppAppearance.accent(accent))
    .appNavigationTitle(
      AppCopy.text("Settings"), language: store.language
    )
    .sheet(isPresented: $showAccentPicker) {
      AccentPickerView(selection: $accent, language: store.language)
    }
    .sheet(item: $supportOffer) { offer in
      SupportTipView(
        offering: offer.offering, package: offer.package,
        language: store.language, accent: accent)
    }
    .fullScreenCover(isPresented: $showIntro) {
      IntroView { showIntro = false }.environmentObject(store)
    }
    .alert(
      AppCopy.text("Paywall unavailable"),
      isPresented: Binding(
        get: { paywallError != nil },
        set: { if !$0 { paywallError = nil } }
      )
    ) {
      Button(AppCopy.text("OK")) { paywallError = nil }
    } message: {
      Text(paywallError ?? "")
    }
  }

  private func openPaywall() async {
    isLoadingSupport = true
    defer { isLoadingSupport = false }
    do {
      guard let offering = try await Purchases.shared.offerings().current else {
        paywallError = AppCopy.text("No support offering is available yet.")
        return
      }
      let tipPackages = offering.availablePackages.filter {
        $0.storeProduct.productType == .consumable
      }
      guard tipPackages.count == 1, let package = tipPackages.first else {
        paywallError = AppCopy.text("No support offering is available yet.")
        return
      }
      supportOffer = SupportOffer(offering: offering, package: package)
    } catch {
      paywallError = error.localizedDescription
    }
  }
}

private struct SupportOffer: Identifiable {
  let offering: Offering
  let package: Package
  var id: String { package.identifier }
}
