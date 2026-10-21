import RevenueCat
import SwiftUI
import UIKit

struct SettingsView: View {
  @EnvironmentObject private var store: AzkarStore
  @EnvironmentObject private var prayerSchedule: PrayerScheduleStore
  let onChooseLocation: () -> Void
  @AppStorage("theme") private var theme = "system"
  @AppStorage("accent") private var accent = "brown"
  @AppStorage(ReaderSettings.scaleKey) private var readerScale = 1.0
  @AppStorage(ReaderSettings.transliterationKey) private var showsTransliteration = false
  @State private var supportOffer: SupportOffer?
  @State private var isLoadingSupport = false
  @State private var paywallError: String?
  @State private var showIntro = false

  var body: some View {
    Form {
      Section {
        VStack(alignment: .leading, spacing: 10) {
          Text(AZLocale.text("Theme", "المظهر")).azText(.rowTitle)
          Picker(AZLocale.text("Theme", "المظهر"), selection: $theme) {
            Text(AZLocale.text("System", "النظام")).tag("system")
            Text(AZLocale.text("Day", "نهاري")).tag("light")
            Text(AZLocale.text("Night", "ليلي")).tag("dark")
          }
          .pickerStyle(.segmented)
          .labelsHidden()
        }
        .padding(.vertical, 6)
        .azFormRow()

        VStack(alignment: .leading, spacing: AZSpace.sm) {
          HStack {
            Text(AZLocale.text("Accent", "لون التمييز")).azText(.rowTitle)
            Spacer()
            Text(AZAccent(storedID: accent).name).azText(.callout).foregroundStyle(AZColor.inkMuted)
          }
          AccentSwatches(selection: $accent)
        }
        .padding(.vertical, 6)
        .azFormRow()

        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
          Link(destination: settingsURL) {
            HStack {
              Text(AZLocale.text("Language", "اللغة")).azText(.rowTitle).foregroundStyle(AZColor.ink)
              Spacer()
              Text(AZLocale.isArabic ? "العربية" : "English").azText(.callout).foregroundStyle(AZColor.inkMuted)
              AZChevron()
            }
          }
          .azFormRow()
        }
      } header: {
        AZFormHeader(title: AZLocale.text("Appearance", "المظهر"))
      }

      Section {
        HStack(spacing: AZSpace.sm) {
          Text(AZLocale.text("Text size", "حجم النص")).azText(.rowTitle)
          Spacer()
          Text(ReaderSettings.label(readerScale)).azText(.callout).foregroundStyle(AZColor.inkMuted)
          ReaderSizeStepper(scale: $readerScale)
        }
        .azFormRow()
        Toggle(isOn: $showsTransliteration) {
          Text(AZLocale.text("Show transliteration", "إظهار النطق اللاتيني")).azText(.rowTitle)
        }
        .tint(AZColor.forest)
        .azFormRow()
      } header: {
        AZFormHeader(title: AZLocale.text("Reading", "القراءة"))
      }

      Section {
        ReminderSettingView(kind: .morning, language: store.language).azFormRow()
        ReminderSettingView(kind: .evening, language: store.language).azFormRow()
      } header: {
        AZFormHeader(title: AZLocale.text("Reminders", "التذكيرات"))
      }

      Section {
        Button(action: onChooseLocation) {
          HStack {
            Text(AZLocale.text("Prayer location", "موقع الصلاة")).azText(.rowTitle).foregroundStyle(AZColor.ink)
            Spacer()
            Text(prayerSchedule.configuration?.displayLocationName(language: store.language)
                 ?? AZLocale.text("Not set", "غير محدد"))
              .azText(.callout)
              .foregroundStyle(AZColor.inkMuted)
              .lineLimit(1)
            AZChevron()
          }
        }
        .azFormRow()
        NavigationLink(value: DetailRoute.prayerSettings) {
          Text(AZLocale.text("Prayer times", "مواقيت الصلاة")).azText(.rowTitle)
        }
        .azFormRow()
      } header: {
        AZFormHeader(title: AZLocale.text("Prayer times", "مواقيت الصلاة"))
      }

      Section {
        Button {
          showIntro = true
        } label: {
          Text(AZLocale.text("View introduction", "عرض المقدمة")).azText(.rowTitle).foregroundStyle(AZColor.ink)
        }
        .azFormRow()
        Button {
          Task { await openPaywall() }
        } label: {
          HStack {
            Text(AZLocale.text("Support the developer", "ادعم المطور")).azText(.rowTitle).foregroundStyle(AZColor.ink)
            Spacer()
            if isLoadingSupport { ProgressView() }
          }
        }
        .disabled(!RevenueCatService.isConfigured || isLoadingSupport)
        .azFormRow()
      } header: {
        AZFormHeader(title: AZLocale.text("About", "عن التطبيق"))
      }

      Section {
        HStack(spacing: AZSpace.sm) {
          Image(systemName: "lock")
            .font(.system(size: 20))
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 2) {
            Text(AZLocale.text("Your journey stays yours.", "رحلتك تبقى لك.")).azText(.headline)
            Text(AZLocale.text("Progress, favourites and prayer coordinates stay on this device.",
                               "التقدم والمفضلة وإحداثيات الصلاة تبقى على هذا الجهاز."))
              .azText(.footnote)
              .opacity(0.82)
          }
        }
        .foregroundStyle(AZColor.onForest)
        .listRowBackground(AZColor.forest)
      }
    }
    .azFormStyle()
    .navigationTitle(AZLocale.text("Settings", "الإعدادات"))
    .sheet(item: $supportOffer) { offer in
      SupportTipView(
        offering: offer.offering, package: offer.package,
        language: store.language, accent: accent)
    }
    .fullScreenCover(isPresented: $showIntro) {
      IntroView { showIntro = false }.environmentObject(store)
    }
    .alert(
      AZLocale.text("Paywall unavailable", "صفحة الدعم غير متاحة"),
      isPresented: Binding(
        get: { paywallError != nil },
        set: { if !$0 { paywallError = nil } }
      )
    ) {
      Button(AZLocale.text("OK", "حسنًا")) { paywallError = nil }
    } message: {
      Text(paywallError ?? "")
    }
  }

  private func openPaywall() async {
    isLoadingSupport = true
    defer { isLoadingSupport = false }
    let unavailable = AZLocale.text("No support offering is available yet.", "لا توجد باقة دعم متاحة حاليًا.")
    do {
      guard let offering = try await Purchases.shared.offerings().current else {
        paywallError = unavailable
        return
      }
      let tipPackages = offering.availablePackages.filter {
        $0.storeProduct.productType == .consumable
      }
      guard tipPackages.count == 1, let package = tipPackages.first else {
        paywallError = unavailable
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

/// Accent choices as a row of discs; the whole app re-tints live.
private struct AccentSwatches: View {
  @Binding var selection: String

  var body: some View {
    HStack(spacing: 14) {
      ForEach(AZAccent.allCases) { option in
        let selected = AZAccent(storedID: selection) == option
        Button {
          withAnimation(AZMotion.curve(AZDuration.base)) { selection = option.rawValue }
        } label: {
          ZStack {
            Circle().fill(option.color)
            Circle().strokeBorder(AZColor.paperRaised, lineWidth: 3)
            if selected {
              Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AZColor.onAccent)
            }
          }
          .frame(width: 40, height: 40)
          .overlay {
            Circle()
              .stroke(selected ? AZColor.ink : AZColor.lineStrong, lineWidth: selected ? 2 : 1)
              .padding(selected ? -1.5 : 0)
          }
          .frame(width: 44, height: 44)
          .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(option.name)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("accent.\(option.rawValue)")
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(AZLocale.text("Accent", "لون التمييز"))
  }
}

/// Smaller / larger reading text in Settings.
private struct ReaderSizeStepper: View {
  @Binding var scale: Double

  var body: some View {
    HStack(spacing: 6) {
      Button { scale = ReaderSettings.step(scale, by: -1) } label: {
        Image(systemName: "textformat.size.smaller")
      }
      .disabled(scale <= ReaderSettings.scales.first!)
      .accessibilityLabel(AZLocale.text("Smaller", "أصغر"))
      Button { scale = ReaderSettings.step(scale, by: 1) } label: {
        Image(systemName: "textformat.size.larger")
      }
      .disabled(scale >= ReaderSettings.scales.last!)
      .accessibilityLabel(AZLocale.text("Larger", "أكبر"))
    }
    .buttonStyle(.azIcon(.filled))
  }
}
