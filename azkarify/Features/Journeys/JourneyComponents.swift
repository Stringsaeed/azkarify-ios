import SwiftUI

/// The Next prayer card on Today: the coming prayer large, all five times beneath.
struct PrayerStrip: View {
  let prayers: [ScheduledPrayer]
  let next: ScheduledPrayer?
  let now: Date
  let locationName: String?
  let format: (Date) -> String?
  let onSetLocation: () -> Void

  var body: some View {
    Button(action: onSetLocation) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 6) {
          Image(systemName: "mappin").font(.system(size: 11, weight: .semibold)).accessibilityHidden(true)
          Text(eyebrow).azText(.eyebrow).lineLimit(1)
        }
        .foregroundStyle(AZColor.inkSoft)
        if let next, !prayers.isEmpty {
          HStack(alignment: .firstTextBaseline) {
            Text(next.prayer.title(language: AZLocale.language)).azText(.title2)
            Spacer(minLength: AZSpace.xs)
            Text(remaining(until: next.time))
              .azText(.callout)
              .monospacedDigit()
              .foregroundStyle(AZColor.inkSoft)
          }
          .padding(.top, 4)
          HStack(spacing: 4) {
            ForEach(prayers) { prayer in column(prayer, isNext: prayer.prayer == next.prayer && isToday(next)) }
          }
          .padding(.top, 14)
        } else {
          Text(AZLocale.text("Set your location for prayer times", "حدد موقعك لأوقات الصلاة"))
            .azText(.title3)
            .padding(.top, 6)
          Text(AZLocale.text("Prayer times are calculated on your phone.", "تُحسب أوقات الصلاة على هاتفك."))
            .azText(.callout)
            .foregroundStyle(AZColor.inkSoft)
            .padding(.top, 2)
          Text(AZLocale.text("Choose a city", "اختر مدينة"))
            .azText(.button, scale: 15.0 / 16.0)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(AZColor.paperRaised, in: Capsule())
            .overlay { Capsule().strokeBorder(.azStampOutline, lineWidth: AZBorder.hairline) }
            .azStamp(AZStamp.sm, shape: Capsule())
            .padding(.top, AZSpace.sm)
        }
      }
      .padding(.top, 18)
      .padding(.horizontal, AZSpace.md)
      .padding(.bottom, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .foregroundStyle(AZColor.ink)
      .background(AZColor.sage, in: RoundedRectangle(cornerRadius: AZRadius.lg, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: AZRadius.lg, style: .continuous)
          .strokeBorder(.azStampOutline, lineWidth: AZBorder.hairline)
      }
    }
    .buttonStyle(AZPressableCardStyle(stamp: AZStamp.md))
    .accessibilityElement(children: .combine)
    .accessibilityHint(AZLocale.text("Change city", "تغيير المدينة"))
    .accessibilityIdentifier("home.prayerLocation")
  }

  private var eyebrow: String {
    let label = AZLocale.text("Next prayer", "الصلاة القادمة")
    guard let locationName, !locationName.isEmpty else { return label }
    return "\(label) · \(locationName)"
  }

  private func isToday(_ prayer: ScheduledPrayer) -> Bool {
    prayers.contains { $0.time == prayer.time }
  }

  private func column(_ prayer: ScheduledPrayer, isNext: Bool) -> some View {
    let past = prayer.time <= now
    return VStack(spacing: 0) {
      Text(prayer.prayer.title(language: AZLocale.language))
        .azText(.footnote)
        .fontWeight(isNext ? .semibold : nil)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      Text(format(prayer.time) ?? "–")
        .azText(.headline)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .foregroundStyle(past && !isNext ? AZColor.inkSoft : AZColor.ink)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity)
    .background {
      if isNext {
        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AZColor.lime)
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(.azStampOutline, lineWidth: AZBorder.hairline)
      }
    }
  }

  private func remaining(until time: Date) -> String {
    let minutes = max(1, Int(time.timeIntervalSince(now) / 60))
    if minutes < 60 {
      return AZLocale.text("in \(minutes) min", "بعد \(AZLocale.number(minutes)) دقيقة")
    }
    let hours = minutes / 60
    let rest = minutes % 60
    if rest == 0 {
      return AZLocale.text("in \(hours) h", "بعد \(AZLocale.number(hours)) ساعة")
    }
    return AZLocale.text("in \(hours) h \(rest) min",
                         "بعد \(AZLocale.number(hours)) س و\(AZLocale.number(rest)) د")
  }
}

/// One journey on Today. The whole card is one button.
struct JourneyCard: View {
  let journey: JourneyDefinition
  let completedCount: Int
  let time: String?
  let isNext: Bool

  private var required: Int { journey.requiredSteps.count }
  private var completed: Bool { completedCount == required }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: AZSpace.sm) {
        AZIconWell(
          systemImage: completed ? "checkmark" : journey.symbol,
          state: completed ? .on : (isNext ? .spark : .idle))
        VStack(alignment: .leading, spacing: 2) {
          Text(journey.title.value(language: AZLocale.language))
            .azText(.headline)
            .multilineTextAlignment(.leading)
          if let time {
            Text(time).azText(.callout).monospacedDigit()
          } else {
            Text(journey.subtitle.value(language: AZLocale.language))
              .azText(.footnote)
              .foregroundStyle(AZColor.inkMuted)
              .multilineTextAlignment(.leading)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        AZChevron()
      }
      HStack(spacing: AZSpace.sm) {
        AZProgressTrack(value: required == 0 ? 0 : Double(completedCount) / Double(required), complete: completed)
        Text(completed ? AZLocale.text("Complete", "مكتملة") : AZLocale.progress(completedCount, of: required))
          .azText(.footnote)
          .fontWeight(.semibold)
          .monospacedDigit()
          .foregroundStyle(completed ? AZColor.forest : AZColor.ink)
      }
    }
    .foregroundStyle(AZColor.ink)
    .azCard(compact: true, stamped: isNext)
    .overlay(alignment: .topTrailing) {
      if isNext {
        AZSticker(label: AZLocale.text("Next", "التالية")) {
          AZOrnament(shape: .star, size: 14, color: AZColor.spark)
        }
        .padding(.trailing, AZSpace.md)
        .offset(y: -14)
        .accessibilityIdentifier("next-prayer-highlight")
      }
    }
    .padding(.top, isNext ? 10 : 0)
    .accessibilityElement(children: .combine)
    .accessibilityValue(AZLocale.text(
      "\(completedCount) of \(AZLocale.steps(required)) completed",
      "اكتملت \(AZLocale.number(completedCount)) من \(AZLocale.steps(required))"))
  }
}

enum StepMarkerState {
  case todo, next, done
}

/// The numbered circle of a journey's timeline. Tapping it completes or reopens the step.
struct StepMarker: View {
  let number: Int
  let state: StepMarkerState

  var body: some View {
    ZStack {
      Circle().fill(fill)
      Circle().strokeBorder(state == .done ? AnyShapeStyle(AZColor.forest) : AnyShapeStyle(.azStampOutline),
                            lineWidth: AZBorder.stamp)
      if state == .done {
        Image(systemName: "checkmark")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(AZColor.onForest)
      } else {
        Text(AZLocale.number(number)).azText(.headline, scale: 15.0 / 17.0).foregroundStyle(AZColor.ink)
      }
    }
    .frame(width: 40, height: 40)
    .modifier(NextStamp(isNext: state == .next))
    .frame(width: 44, height: 44)
  }

  private var fill: Color {
    switch state {
    case .todo: AZColor.paperRaised
    case .next: AZColor.lime
    case .done: AZColor.forest
    }
  }

  private struct NextStamp: ViewModifier {
    let isNext: Bool
    func body(content: Content) -> some View {
      if isNext { content.azStamp(AZStamp.sm, shape: Circle()) } else { content }
    }
  }
}

/// The dashed rail between steps; solid `forest` once the step above is done.
struct StepRail: View {
  let done: Bool

  var body: some View {
    Line()
      .stroke(done ? AZColor.forest : AZColor.lineStrong,
              style: StrokeStyle(lineWidth: AZBorder.stamp, dash: done ? [] : [4, 4]))
      .frame(width: AZBorder.stamp)
      .frame(maxHeight: .infinity)
      .padding(.vertical, 4)
      .accessibilityHidden(true)
  }

  private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
      var path = Path()
      path.move(to: CGPoint(x: rect.midX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
      return path
    }
  }
}
