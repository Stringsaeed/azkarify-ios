import SwiftUI

struct JourneyDetailView: View {
  @EnvironmentObject private var store: AzkarStore
  @EnvironmentObject private var schedule: PrayerScheduleStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("accent") private var accent = "brown"
  @State private var audio = CounterAudio()
  @State private var confettiToken = 0
  let journey: JourneyDefinition
  @ObservedObject var progress: JourneyProgressStore

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          header(on: context.date)
          VStack(spacing: 0) {
            ForEach(Array(journey.steps.enumerated()), id: \.element.id) { index, step in
              stepRow(step, index: index, on: context.date)
            }
          }
        }
        .padding(20)
        .padding(.bottom, 28)
      }
      .background { BotanicalBackground(accent: accent, variant: 3) }
      .appNavigationTitle(journey.title.value(language: store.language), language: store.language)
      .toolbar {
        ToolbarItem(placement: store.language == "ar" ? .topBarLeading : .topBarTrailing) {
          JourneyPointsButton()
        }
      }
      .accessibilityIdentifier("journeyDetail-\(journey.id)")
    }
    .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
    .onAppear { audio.prepare() }
    .onDisappear { audio.stop() }
    .confettiBurst(token: $confettiToken, accent: accent)
  }

  private func header(on date: Date) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(journey.subtitle.value(language: store.language))
        .font(AppAppearance.font(size: 23, relativeTo: .title2, bold: true))
      if let prayer = journey.prayer,
        let time = schedule.formattedTime(for: prayer, on: date, language: store.language)
      {
        Label(time, systemImage: "clock")
          .font(AppAppearance.font(size: 16))
          .foregroundStyle(AppAppearance.accent(accent))
      } else if journey.prayer != nil, schedule.configuration != nil {
        Text(text("Prayer time is unavailable for this date and location.",
                  "وقت الصلاة غير متاح لهذا اليوم وهذا الموقع."))
          .font(AppAppearance.font(size: 14))
          .foregroundStyle(.secondary)
      }
      Text(text("Complete each step when you're ready. Your progress starts fresh each day.",
                "أكمل كل خطوة عندما تكون مستعداً. تبدأ رحلة جديدة كل يوم."))
        .font(AppAppearance.font(size: 14))
        .foregroundStyle(.secondary)
      HStack {
        Text(progress.isComplete(journey, on: date)
             ? text("Journey complete", "اكتملت الرحلة")
             : text("Your progress", "تقدمك"))
          .font(AppAppearance.font(size: 16, bold: true))
          .accessibilityIdentifier("journey-completion")
        Spacer()
        Text("\(progress.completedCount(for: journey, on: date)) / \(journey.requiredSteps.count)")
          .font(AppAppearance.font(size: 14))
      }
      .foregroundStyle(AppAppearance.accent(accent))
      ProgressView(value: Double(progress.completedCount(for: journey, on: date)),
                   total: Double(journey.requiredSteps.count))
        .tint(AppAppearance.accent(accent))
        .accessibilityLabel(text("Journey progress", "تقدم الرحلة"))
    }
  }

  private func stepRow(_ step: JourneyStep, index: Int, on date: Date) -> some View {
    let completed = progress.isComplete(step, in: journey, on: date)
    let currentProgress = progress.progress(for: journey, on: date)
    let needsChoice = !step.options.isEmpty && currentProgress.choices[step.id] == nil
    return HStack(alignment: .top, spacing: 12) {
      VStack(spacing: 0) {
        Button {
          let update = withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
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
            confettiToken += 1
          }
        } label: {
          ZStack {
            Circle()
              .fill(completed ? AppAppearance.accent(accent) : AppAppearance.background(accent))
            Circle().strokeBorder(AppAppearance.accent(accent).opacity(0.55), lineWidth: 1)
            if completed {
              Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppAppearance.background(accent))
            } else {
              Text("\(index + 1)")
                .font(AppAppearance.font(size: 15, bold: true))
                .foregroundStyle(AppAppearance.accent(accent))
            }
          }
          .frame(width: 38, height: 38)
          .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(needsChoice)
        .accessibilityLabel(
          text(completed ? "Mark incomplete: " : "Mark complete: ",
               completed ? "إلغاء إكمال: " : "إكمال: ") + step.title.value(language: store.language))
        .accessibilityAddTraits(completed ? .isSelected : [])
        .accessibilityValue(completed ? text("Complete", "مكتملة") : text("Incomplete", "غير مكتملة"))
        .accessibilityIdentifier("journey-step-\(step.id)")
        if index < journey.steps.count - 1 {
          Rectangle().fill(AppAppearance.accent(accent).opacity(0.18))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
        }
      }
      VStack(alignment: .leading, spacing: 10) {
        VStack(alignment: .leading, spacing: 5) {
          Text(step.title.value(language: store.language))
            .font(AppAppearance.font(size: 18, relativeTo: .headline, bold: true))
          if step.isOptional {
            Text(text("Optional", "اختيارية"))
              .font(AppAppearance.font(size: 12))
              .foregroundStyle(AppAppearance.accent(accent))
          }
          if let note = step.note {
            Text(note.value(language: store.language))
              .font(AppAppearance.font(size: 14))
              .foregroundStyle(.secondary)
          }
        }
        if !step.options.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(step.options) { option in
              Button {
                progress.choose(option, for: step, in: journey, on: date)
              } label: {
                HStack(spacing: 8) {
                  Image(systemName: currentProgress.choices[step.id] == option.id
                        ? "largecircle.fill.circle" : "circle")
                  Text(option.title.value(language: store.language))
                    .font(AppAppearance.font(size: 15))
                  Spacer(minLength: 0)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .foregroundStyle(AppAppearance.accent(accent))
              .accessibilityAddTraits(currentProgress.choices[step.id] == option.id ? .isSelected : [])
              .accessibilityIdentifier("journey-choice-\(option.id)")
            }
          }
        }
        ForEach(step.categoryIDs, id: \.self) { categoryID in
          if let category = store.categories.first(where: { $0.id == categoryID }) {
            NavigationLink(value: DetailRoute.category(category)) {
              HStack(spacing: 8) {
                Image(systemName: "book.closed")
                  .font(.system(size: 13))
                Text(category.title)
                  .font(AppAppearance.font(size: 14))
                  .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward").font(.caption2)
              }
              .frame(minHeight: 44)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppAppearance.accent(accent))
            .accessibilityIdentifier("journey-category-\(categoryID)")
          }
        }
        if !step.categoryIDs.isEmpty && store.categories.isEmpty {
          if store.isLoading {
            ProgressView().accessibilityLabel(text("Loading azkar", "تحميل الأذكار"))
          } else {
            Button(text("Load azkar", "تحميل الأذكار")) { Task { await store.load() } }
              .font(AppAppearance.font(size: 14))
              .frame(minHeight: 44)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .strokeBorder(AppAppearance.accent(accent).opacity(completed ? 0.3 : 0.10), lineWidth: 1)
      }
      .padding(.bottom, 16)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private func text(_ english: String, _ arabic: String) -> String {
    JourneyText(english, arabic).value(language: store.language)
  }
}
