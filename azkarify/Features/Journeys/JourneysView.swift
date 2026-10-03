import SwiftUI

struct JourneysView: View {
  @EnvironmentObject private var store: AzkarStore
  @EnvironmentObject private var schedule: PrayerScheduleStore
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage("accent") private var accent = "brown"
  @EnvironmentObject private var progress: JourneyProgressStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var showPrayerSettings = false
  @State private var showLocationSetup = false
  @State private var openSettingsAfterLocation = false

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          introduction(date: context.date)
          journeySection(
            text("Begin your day", "بداية يومك"),
            journeys: [JourneyCatalog.morning, JourneyCatalog.goingOut], date: context.date)
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              sectionTitle(text("Your prayer journeys", "رحلات الصلاة"))
              Spacer()
              Button { showPrayerSettings = true } label: {
                Image(systemName: "clock.badge.checkmark")
                  .frame(minWidth: 44, minHeight: 44)
              }
              .accessibilityLabel(text("Set prayer times", "ضبط أوقات الصلاة"))
            }
            if schedule.configuration == nil {
              Button { showPrayerSettings = true } label: {
                Label(text("Set your location for prayer times", "حدد موقعك لأوقات الصلاة"),
                      systemImage: "location")
                  .font(AppAppearance.font(size: 14))
                  .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
              }
              .buttonStyle(.plain)
              .foregroundStyle(AppAppearance.accent(accent))
            } else if schedule.prayers(on: context.date).isEmpty {
              Text(text("Prayer times are unavailable for this date and location.",
                        "أوقات الصلاة غير متاحة لهذا اليوم وهذا الموقع."))
                .font(AppAppearance.font(size: 14))
                .foregroundStyle(.secondary)
            }
            ForEach(JourneyCatalog.prayers) { journey in
              journeyLink(journey, date: context.date)
            }
          }
          journeySection(
            text("As the day settles", "ختام يومك"),
            journeys: [JourneyCatalog.evening, JourneyCatalog.sleep], date: context.date)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .padding(.bottom, 28)
      }
      .background { BotanicalBackground(accent: accent, variant: 2) }
      .navigationTitle(text("Journeys", "الرحلات"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          PrayerLocationTitle(title: text("Journeys", "الرحلات"), language: store.language,
                              location: schedule.configuration?.displayLocationName(language: store.language)) {
            showLocationSetup = true
          }
        }
        ToolbarItem(placement: store.language == "ar" ? .topBarLeading : .topBarTrailing) { JourneyPointsButton() }
      }
      .accessibilityIdentifier("journeysScreen")
    }
    .sheet(isPresented: $showPrayerSettings, onDismiss: { schedule.refresh() }) {
      NavigationStack { PrayerScheduleSettingsView() }
    }
    .sheet(isPresented: $showLocationSetup, onDismiss: {
      if openSettingsAfterLocation {
        openSettingsAfterLocation = false
        showPrayerSettings = true
      }
    }) {
      PrayerLocationSheet(onFinish: { showLocationSetup = false }, onOpenSettings: {
        openSettingsAfterLocation = true
        showLocationSetup = false
      })

      .presentationDragIndicator(.visible)
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { schedule.refresh() }
    }
    .task { schedule.refresh() }
    .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
  }

  private func introduction(date: Date) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 8) {
          Text(text("A little, every day", "قليل يدوم كل يوم"))
            .font(AppAppearance.font(size: 29, relativeTo: .title, bold: true))
          Text(text("Follow a journey at your own pace.", "أكمل رحلتك على مهل."))
            .font(AppAppearance.font(size: 16))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        JourneyCrescent(accent: accent)
          .frame(width: 84, height: 110)
      }
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          Image(systemName: "leaf")
            .font(.system(size: 22))
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 3) {
            Text(text("Today's progress", "إنجازك اليوم"))
              .font(AppAppearance.font(size: 15, bold: true))
            Text(text("of your day complete", "من يومك مكتمل"))
              .font(AppAppearance.font(size: 13))
              .foregroundStyle(.secondary)
          }
          Spacer(minLength: 0)
          Text(dayProgressPercentage(on: date))
            .font(AppAppearance.font(size: 28, relativeTo: .title2, bold: true))
            .monospacedDigit()
        }
        ProgressView(value: progress.dayProgress(on: date))
          .tint(AppAppearance.accent(accent))
          .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: progress.dayProgress(on: date))
      }
      .foregroundStyle(AppAppearance.accent(accent))
      .padding(16)
      .background(AppAppearance.accent(accent).opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(text("Today's progress", "إنجازك اليوم"))
      .accessibilityValue(dayProgressPercentage(on: date))
      .accessibilityIdentifier("daily-progress")
    }
  }

  private func dayProgressPercentage(on date: Date) -> String {
    progress.dayProgress(on: date).formatted(
      .percent.precision(.fractionLength(0)).locale(Locale(identifier: store.language)))
  }

  private func journeySection(_ title: String, journeys: [JourneyDefinition], date: Date) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle(title)
      ForEach(journeys) { journey in journeyLink(journey, date: date) }
    }
  }

  private func sectionTitle(_ title: String) -> some View {
    Text(title).font(AppAppearance.font(size: 20, relativeTo: .headline, bold: true))
  }

  private func journeyLink(_ journey: JourneyDefinition, date: Date) -> some View {
    NavigationLink(value: DetailRoute.journey(journey)) {
      JourneyCard(
        journey: journey, completedCount: progress.completedCount(for: journey, on: date),
        time: journey.prayer.flatMap { schedule.formattedTime(for: $0, on: date, language: store.language) },
        language: store.language, accent: accent,
        isNextPrayer: journey.id == PrayerJourneyHighlight.nextJourneyID(
          on: date, prayers: schedule.prayers(on: date),
          completedJourneyIDs: Set(JourneyCatalog.prayers.filter {
            progress.isComplete($0, on: date)
          }.map(\.id))))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("journey-\(journey.id)")
  }

  private func text(_ english: String, _ arabic: String) -> String {
    JourneyText(english, arabic).value(language: store.language)
  }
}

private struct JourneyCard: View {
  let journey: JourneyDefinition
  let completedCount: Int
  let time: String?
  let language: String
  let accent: String
  let isNextPrayer: Bool

  private var completed: Bool { completedCount == journey.requiredSteps.count }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      if isNextPrayer {
        Label(language == "ar" ? "الصلاة القادمة" : "Next prayer", systemImage: "clock.fill")
          .font(AppAppearance.font(size: 13, bold: true))
          .foregroundStyle(AppAppearance.accent(accent))
          .accessibilityIdentifier("next-prayer-highlight")
      }
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: completed ? "checkmark" : journey.symbol)
          .font(.system(size: 22, weight: .light))
          .foregroundStyle(AppAppearance.accent(accent))
          .frame(width: 44, height: 44)
          .background(AppAppearance.accent(accent).opacity(0.08), in: Circle())
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 5) {
          Text(journey.title.value(language: language))
            .font(AppAppearance.font(size: 18, relativeTo: .headline, bold: true))
          if let time {
            Text(time)
              .font(AppAppearance.font(size: 14))
              .foregroundStyle(AppAppearance.accent(accent))
          } else {
            Text(journey.subtitle.value(language: language))
              .font(AppAppearance.font(size: 13))
              .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "chevron.forward")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .padding(.top, 14)
          .accessibilityHidden(true)
      }
      HStack(spacing: 12) {
        ProgressView(value: Double(completedCount), total: Double(journey.requiredSteps.count))
          .tint(AppAppearance.accent(accent))
          .accessibilityHidden(true)
        Text(JourneyText(
          completed ? "Complete" : "\(completedCount) / \(journey.requiredSteps.count)",
          completed ? "مكتملة" : "\(completedCount) / \(journey.requiredSteps.count)"
        ).value(language: language))
          .font(AppAppearance.font(size: 12, bold: true))
          .foregroundStyle(AppAppearance.accent(accent))
      }
    }
    .padding(18)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .strokeBorder(AppAppearance.accent(accent).opacity(isNextPrayer ? 0.8 : completed ? 0.3 : 0.12), lineWidth: isNextPrayer ? 2 : 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityValue(JourneyText(
      "\(completedCount) of \(journey.requiredSteps.count) steps completed",
      "اكتملت \(completedCount) من \(journey.requiredSteps.count) خطوات"
    ).value(language: language))
  }
}
