import RevenueCat
import RevenueCatUI
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var store: AzkarStore
  @AppStorage("theme") private var theme = "system"
  @AppStorage("font") private var font = "ibmPlexSansArabic"
  @AppStorage("accent") private var accent = "brown"
  @State private var showPaywall = false
  @State private var paywallError: String?
  @State private var showIntro = false
  @State private var showAccentPicker = false

  var body: some View {
    Form {
      Picker(AppCopy.text("Theme", "المظهر", language: store.language), selection: $theme) {
        Text(AppCopy.text("System", "النظام", language: store.language)).tag("system")
        Text(AppCopy.text("Light", "فاتح", language: store.language)).tag("light")
        Text(AppCopy.text("Dark", "داكن", language: store.language)).tag("dark")
      }
      Picker(
        AppCopy.text("Language", "اللغة", language: store.language), selection: $store.language
      ) {
        Text("العربية").tag("ar")
        Text("English").tag("en")
      }
      if store.language == "ar" {
        Picker("الخط", selection: $font) {
          Text("أميري · Amiri").tag("amiri")
          Text("الرقعة · Aref Ruqaa").tag("arefRuqaa")
          Text("آي بي إم بلكس · IBM Plex Sans Arabic").tag("ibmPlexSansArabic")
        }
      } else {
        LabeledContent("Font", value: "Open Sans")
      }
      Button {
        showAccentPicker = true
      } label: {
        HStack {
          Text(AppCopy.text("Accent color", "لون التمييز", language: store.language))
          Spacer()
          Circle()
            .fill(AppAppearance.accent(accent))
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
        }
      }
      Section(AppCopy.text("Reminders", "التذكيرات", language: store.language)) {
        ReminderSettingView(kind: .morning, language: store.language)
        ReminderSettingView(kind: .evening, language: store.language)
      }
      Button(AppCopy.text("View introduction", "عرض المقدمة", language: store.language)) {
        showIntro = true
      }
      Button(AppCopy.text("Support the developer", "ادعم المطور", language: store.language)) {
        Task { await openPaywall() }
      }
      .disabled(!RevenueCatService.isConfigured)
    }
    .scrollContentBackground(.hidden)
    .background(AppAppearance.background)
    .font(AppAppearance.font(language: store.language, choice: font, size: 17))
    .tint(AppAppearance.accent(accent))
    .appNavigationTitle(
      AppCopy.text("Settings", "الإعدادات", language: store.language), language: store.language
    )
    .sheet(isPresented: $showAccentPicker) {
      AccentPickerView(selection: $accent, language: store.language)
    }
    .sheet(isPresented: $showPaywall) { PaywallView() }
    .fullScreenCover(isPresented: $showIntro) {
      IntroView { showIntro = false }.environmentObject(store)
    }
    .alert(
      AppCopy.text("Paywall unavailable", "صفحة الدعم غير متاحة", language: store.language),
      isPresented: Binding(
        get: { paywallError != nil },
        set: { if !$0 { paywallError = nil } }
      )
    ) {
      Button(AppCopy.text("OK", "حسنًا", language: store.language)) { paywallError = nil }
    } message: {
      Text(paywallError ?? "")
    }
  }

  private func openPaywall() async {
    do {
      guard try await Purchases.shared.offerings().current != nil else {
        paywallError = AppCopy.text(
          "No support offering is available yet.", "لا توجد باقة دعم متاحة حاليًا.",
          language: store.language)
        return
      }
      showPaywall = true
    } catch {
      paywallError = error.localizedDescription
    }
  }
}
