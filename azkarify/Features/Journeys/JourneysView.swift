import SwiftUI

/// The Today tab: greeting, next prayer, the day's progress and its journeys.
struct TodayView: View {
  @EnvironmentObject private var schedule: PrayerScheduleStore
  @EnvironmentObject private var progress: JourneyProgressStore
  @Environment(\.scenePhase) private var scenePhase
  let onChooseLocation: () -> Void
  @State private var showPrayerSettings = false

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      let date = context.date
      let prayers = schedule.prayers(on: date)
      let nextJourneyID = PrayerJourneyHighlight.nextJourneyID(
        on: date, prayers: prayers,
        completedJourneyIDs: Set(JourneyCatalog.prayers.filter { progress.isComplete($0, on: date) }.map(\.id)))
      ScrollView {
        VStack(alignment: .leading, spacing: AZSpace.xl) {
          greeting(on: date, prayers: prayers)
          dayProgress(on: date)
          PrayerStrip(
            prayers: prayers, next: schedule.nextPrayer(after: date), now: date,
            locationName: schedule.configuration?.displayLocationName(language: AZLocale.language),
            format: { schedule.formatted($0, language: AZLocale.language, compact: true) },
            onSetLocation: onChooseLocation)
          section(
            eyebrow: AZLocale.text("01 / Morning", "٠١ / الصباح"),
            title: AZLocale.text("Begin your day", "بداية يومك"),
            journeys: [JourneyCatalog.morning, JourneyCatalog.goingOut], date: date, nextID: nil)
          VStack(alignment: .leading, spacing: AZSpace.sm) {
            AZSectionHeader(
              eyebrow: AZLocale.text("02 / Prayer", "٠٢ / الصلاة"),
              title: AZLocale.text("Your prayer journeys", "رحلات الصلاة")
            ) {
              Button(AZLocale.text("Prayer times", "المواقيت")) { showPrayerSettings = true }
                .foregroundStyle(.tint)
                .accessibilityLabel(AZLocale.text("Set prayer times", "ضبط أوقات الصلاة"))
            }
            if schedule.configuration != nil && prayers.isEmpty {
              Text(AZLocale.text("Prayer times are unavailable for this date and location.",
                                 "أوقات الصلاة غير متاحة لهذا اليوم وهذا الموقع."))
                .azText(.callout)
                .foregroundStyle(AZColor.inkMuted)
            }
            ForEach(JourneyCatalog.prayers) { journey in
              journeyLink(journey, date: date, prayers: prayers, isNext: journey.id == nextJourneyID)
            }
          }
          section(
            eyebrow: AZLocale.text("03 / Evening", "٠٣ / المساء"),
            title: AZLocale.text("As the day settles", "ختام يومك"),
            journeys: [JourneyCatalog.evening, JourneyCatalog.sleep], date: date, nextID: nil)
        }
        .foregroundStyle(AZColor.ink)
        .padding(.horizontal, AZSpace.gutter)
        .padding(.top, AZSpace.xs)
        .padding(.bottom, AZSpace.xxl)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
      }
      .azScreenBackground()
      .accessibilityIdentifier("journeysScreen")
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button(action: onChooseLocation) {
          HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
            Text(schedule.configuration?.displayLocationName(language: AZLocale.language)
                 ?? AZLocale.text("Choose a city", "اختر مدينة"))
              .azText(.headline, scale: 15.0 / 17.0)
              .lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
          }
          .foregroundStyle(AZColor.ink)
          .frame(maxWidth: 200)
        }
        .accessibilityLabel(AZLocale.text("Prayer location", "موقع الصلاة"))
        .accessibilityValue(schedule.configuration?.displayLocationName(language: AZLocale.language) ?? "")
        .accessibilityIdentifier("today.location")
      }
      ToolbarItem(placement: .topBarTrailing) { PointsToolbarButton() }
        .sharedBackgroundVisibility(.hidden)
    }
    .toolbarTitleDisplayMode(.inline)
    .sheet(isPresented: $showPrayerSettings, onDismiss: { schedule.refresh() }) {
      NavigationStack { PrayerScheduleSettingsView() }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { schedule.refresh() }
    }
  }

  private func isEvening(_ date: Date, prayers: [ScheduledPrayer]) -> Bool {
    if let maghrib = prayers.first(where: { $0.prayer == .maghrib }) { return date >= maghrib.time }
    return Calendar.current.component(.hour, from: date) >= 18
  }

  private func greeting(on date: Date, prayers: [ScheduledPrayer]) -> some View {
    let evening = isEvening(date, prayers: prayers)
    return HStack(alignment: .top, spacing: AZSpace.sm) {
      VStack(alignment: .leading, spacing: AZSpace.xs) {
        Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(AZLocale.locale)))
          .azText(.eyebrow)
          .foregroundStyle(AZColor.sparkInk)
        Text(evening
             ? AZLocale.text("A softer\nending.", "ختام أهدأ\nليومك.")
             : AZLocale.text("A little,\nevery day.", "قليل يدوم\nكل يوم."))
          .azText(.display)
          .accessibilityAddTraits(.isHeader)
      }
      Spacer(minLength: 0)
      AZOrnament(
        shape: evening ? .crescent : .star, size: 64, color: evening ? AZColor.clay : AZColor.spark,
        spins: !evening)
        .padding(.top, 14)
    }
  }

  private func dayProgress(on date: Date) -> some View {
    let value = progress.dayProgress(on: date)
    let percentage = value.formatted(.percent.precision(.fractionLength(0)).locale(AZLocale.locale))
    return VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: AZSpace.xs) {
        Text(percentage).azText(.title2).monospacedDigit()
        Text(AZLocale.text("of today's journeys complete", "من رحلات اليوم مكتملة"))
          .azText(.callout)
          .foregroundStyle(AZColor.inkMuted)
      }
      AZProgressTrack(value: value)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AZLocale.text("Today's progress", "إنجازك اليوم"))
    .accessibilityValue(percentage)
    .accessibilityIdentifier("daily-progress")
  }

  private func section(
    eyebrow: String, title: String, journeys: [JourneyDefinition], date: Date, nextID: String?
  ) -> some View {
    VStack(alignment: .leading, spacing: AZSpace.sm) {
      AZSectionHeader(eyebrow: eyebrow, title: title)
      ForEach(journeys) { journey in
        journeyLink(journey, date: date, prayers: [], isNext: journey.id == nextID)
      }
    }
  }

  private func journeyLink(
    _ journey: JourneyDefinition, date: Date, prayers: [ScheduledPrayer], isNext: Bool
  ) -> some View {
    let time = journey.prayer.flatMap { prayer in
      prayers.first { $0.prayer == prayer }.flatMap { schedule.formatted($0.time, language: AZLocale.language) }
    }
    return NavigationLink(value: DetailRoute.journey(journey)) {
      JourneyCard(
        journey: journey, completedCount: progress.completedCount(for: journey, on: date),
        time: time,
        isNext: isNext)
    }
    .buttonStyle(AZPressableCardStyle(radius: AZRadius.md))
    .accessibilityIdentifier("journey-\(journey.id)")
  }
}
