import SwiftUI

struct JourneyDetailView: View {
  @EnvironmentObject private var store: AzkarStore
  @EnvironmentObject private var schedule: PrayerScheduleStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var audio = CounterAudio()
  @State private var completion: CompletionSummary?
  @State private var focusCategory: ZikrCategory?
  let journey: JourneyDefinition
  @ObservedObject var progress: JourneyProgressStore

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      let date = context.date
      let nextStepID = journey.steps.first { !progress.isComplete($0, in: journey, on: date) && !$0.isOptional }?.id
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          header(on: date)
          VStack(spacing: 0) {
            ForEach(Array(journey.steps.enumerated()), id: \.element.id) { index, step in
              stepRow(step, index: index, isNext: step.id == nextStepID, on: date)
            }
          }
        }
        .foregroundStyle(AZColor.ink)
        .padding(.horizontal, AZSpace.gutter)
        .padding(.top, AZSpace.md)
        .padding(.bottom, AZSpace.xxl)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
      }
      .azScreenBackground()
      .navigationTitle(journey.title.value(language: AZLocale.language))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { PointsToolbarButton() }
          .sharedBackgroundVisibility(.hidden)
      }
      .accessibilityIdentifier("journeyDetail-\(journey.id)")
    }
    .onAppear { audio.prepare() }
    .onDisappear { audio.stop() }
    .sheet(item: $completion) { CompletionSheet(summary: $0) }
    .fullScreenCover(item: $focusCategory) { category in
      FocusModeLoader(category: category)
    }
  }

  private var sectionEyebrow: String {
    switch journey.id {
    case JourneyCatalog.morning.id, JourneyCatalog.goingOut.id: AZLocale.text("01 / Morning", "٠١ / الصباح")
    case JourneyCatalog.evening.id, JourneyCatalog.sleep.id: AZLocale.text("03 / Evening", "٠٣ / المساء")
    default: AZLocale.text("02 / Prayer", "٠٢ / الصلاة")
    }
  }

  private func header(on date: Date) -> some View {
    let done = progress.completedCount(for: journey, on: date)
    let required = journey.requiredSteps.count
    let complete = progress.isComplete(journey, on: date)
    let steps = AZLocale.steps(journey.steps.count)
    return VStack(alignment: .leading, spacing: 10) {
      Text("\(sectionEyebrow) · \(steps)").azText(.eyebrow).foregroundStyle(AZColor.sparkInk)
      Text(journey.subtitle.value(language: AZLocale.language))
        .azText(.title1)
        .accessibilityAddTraits(.isHeader)
      if let prayer = journey.prayer {
        if let time = schedule.formattedTime(for: prayer, on: date, language: AZLocale.language) {
          Label(time, systemImage: "clock")
            .azText(.callout)
            .monospacedDigit()
            .foregroundStyle(AZColor.inkMuted)
        } else if schedule.configuration != nil {
          Text(AZLocale.text("Prayer time is unavailable for this date and location.",
                             "وقت الصلاة غير متاح لهذا اليوم وهذا الموقع."))
            .azText(.callout)
            .foregroundStyle(AZColor.inkMuted)
        }
      }
      Text(AZLocale.text("Complete each step when you're ready. Your progress starts fresh each day.",
                         "أكمل كل خطوة عندما تكون مستعداً. تبدأ رحلة جديدة كل يوم."))
        .azText(.callout)
        .foregroundStyle(AZColor.inkMuted)
      HStack(spacing: AZSpace.sm) {
        AZProgressTrack(value: required == 0 ? 0 : Double(done) / Double(required), complete: complete)
          .accessibilityHidden(false)
          .accessibilityLabel(AZLocale.text("Journey progress", "تقدم الرحلة"))
        Text(complete ? AZLocale.text("Journey complete", "اكتملت الرحلة") : AZLocale.progress(done, of: required))
          .azText(.footnote)
          .fontWeight(.semibold)
          .monospacedDigit()
          .foregroundStyle(complete ? AZColor.forest : AZColor.ink)
          .accessibilityIdentifier("journey-completion")
      }
      .padding(.top, 4)
    }
  }

  private func stepRow(_ step: JourneyStep, index: Int, isNext: Bool, on date: Date) -> some View {
    let completed = progress.isComplete(step, in: journey, on: date)
    let currentProgress = progress.progress(for: journey, on: date)
    let needsChoice = !step.options.isEmpty && currentProgress.choices[step.id] == nil
    let isLast = index == journey.steps.count - 1
    return HStack(alignment: .top, spacing: AZSpace.sm) {
      VStack(spacing: 0) {
        Button { toggle(step, on: date) } label: {
          StepMarker(number: index + 1, state: completed ? .done : (isNext && !needsChoice ? .next : .todo))
        }
        .buttonStyle(.plain)
        .disabled(needsChoice)
        .accessibilityLabel(
          AZLocale.text(completed ? "Mark incomplete: " : "Mark complete: ",
                        completed ? "إلغاء إكمال: " : "إكمال: ") + step.title.value(language: AZLocale.language))
        .accessibilityAddTraits(completed ? .isSelected : [])
        .accessibilityValue(completed ? AZLocale.text("Complete", "مكتملة") : AZLocale.text("Incomplete", "غير مكتملة"))
        .accessibilityIdentifier("journey-step-\(step.id)")
        if !isLast { StepRail(done: completed) }
      }
      .frame(width: 44)
      .accessibilityElement(children: .contain)

      Group {
        if isNext && !completed {
          nextStepCard(step, currentProgress: currentProgress, on: date)
        } else {
          stepContent(step, currentProgress: currentProgress, on: date)
            .padding(.top, 8)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.bottom, isLast ? 0 : 20)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private func nextStepCard(_ step: JourneyStep, currentProgress: JourneyProgress, on date: Date) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(step.title.value(language: AZLocale.language)).azText(.headline)
        Spacer(minLength: AZSpace.xs)
        AZPill(label: AZLocale.text("Up next", "التالية"))
      }
      stepDetails(step, currentProgress: currentProgress, compactLinks: false)
      if let category = step.categoryIDs.lazy.compactMap({ id in store.categories.first { $0.id == id } }).first {
        Button(AZLocale.text("Start reading", "ابدأ القراءة")) { focusCategory = category }
          .buttonStyle(.az(.primary, small: true))
          .accessibilityIdentifier("journey-start-\(step.id)")
      }
    }
    .azCard(compact: true)
  }

  private func stepContent(_ step: JourneyStep, currentProgress: JourneyProgress, on date: Date) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: AZSpace.xs) {
        Text(step.title.value(language: AZLocale.language)).azText(.headline)
        if step.isOptional { AZPill(label: AZLocale.text("Optional", "اختيارية"), tone: .muted) }
      }
      stepDetails(step, currentProgress: currentProgress, compactLinks: true)
    }
  }

  @ViewBuilder
  private func stepDetails(_ step: JourneyStep, currentProgress: JourneyProgress, compactLinks: Bool) -> some View {
    if let note = step.note {
      Text(note.value(language: AZLocale.language))
        .azText(.footnote)
        .foregroundStyle(AZColor.inkMuted)
    }
    if !step.options.isEmpty {
      HStack(spacing: AZSpace.xs) {
        ForEach(step.options) { option in
          AZChip(title: option.title.value(language: AZLocale.language),
                 isSelected: currentProgress.choices[step.id] == option.id) {
            progress.choose(option, for: step, in: journey, on: Date())
          }
          .accessibilityIdentifier("journey-choice-\(option.id)")
        }
      }
      .padding(.top, 6)
    }
    ForEach(step.categoryIDs, id: \.self) { categoryID in
      if let category = store.categories.first(where: { $0.id == categoryID }) {
        NavigationLink(value: DetailRoute.category(category)) {
          HStack(spacing: AZSpace.xs) {
            Image(systemName: "book").font(.system(size: 14)).accessibilityHidden(true)
            Text(category.title)
              .azText(.callout)
              .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if !compactLinks { AZChevron() }
          }
          .foregroundStyle(.tint)
          .frame(minHeight: 44)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("journey-category-\(categoryID)")
      }
    }
    if !step.categoryIDs.isEmpty && store.categories.isEmpty {
      if store.isLoading {
        ProgressView().accessibilityLabel(AZLocale.text("Loading azkar", "تحميل الأذكار"))
      } else {
        Button(AZLocale.text("Load azkar", "تحميل الأذكار")) { Task { await store.load() } }
          .buttonStyle(.azText)
      }
    }
  }

  private func toggle(_ step: JourneyStep, on date: Date) {
    let before = progress.totalPoints
    let update = withAnimation(AZMotion.animation(AZDuration.fast, reduceMotion: reduceMotion)) {
      progress.toggle(step, in: journey, on: date)
    }
    switch update {
    case .unchanged:
      break
    case .reopened:
      audio.play(.reset)
    case .progressed:
      audio.play(.tick)
    case .completedJourney:
      audio.play(.completion)
      let required = journey.requiredSteps.count
      completion = CompletionSummary(
        stickerLabel: AZLocale.text("Journey complete", "اكتملت الرحلة"),
        title: journey.title.value(language: AZLocale.language),
        message: AZLocale.text(
          required == 1 ? "Done for today." : "All \(required) steps, done for today.",
          required == 1 ? "تمّت لليوم." : "أتممت الخطوات كلها لليوم."),
        pointsEarned: progress.totalPoints - before,
        totalPoints: progress.totalPoints)
    }
  }
}

/// Loads a category's entries and opens focus mode straight away (journey "Start reading", Quick start).
struct FocusModeLoader: View {
  @EnvironmentObject private var store: AzkarStore
  @EnvironmentObject private var progress: JourneyProgressStore
  @Environment(\.dismiss) private var dismiss
  let category: ZikrCategory
  @State private var entries: [ZikrEntry]?

  var body: some View {
    Group {
      if let entries {
        FocusModeView(entries: entries, title: category.title) {
          _ = progress.completeSlideshow(categoryID: category.id)
        }
      } else {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).azScreenBackground()
      }
    }
    .task {
      entries = (try? store.repository.entries(for: category)) ?? []
      if entries?.isEmpty == true { dismiss() }
    }
  }
}
