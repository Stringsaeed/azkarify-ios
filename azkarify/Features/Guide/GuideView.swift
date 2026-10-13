import SwiftUI

private struct StandingCursor {
  let categoryID: Int
  let posture: String
  let lines: [GuideLine]
  var index: Int

  var line: GuideLine { lines[index] }
  var canBack: Bool { index > 0 }
  var canNext: Bool { index + 1 < lines.count }
  var accessibilityValue: String { "\(categoryID)-\(line.id)" }

  mutating func goBack() {
    if canBack { index -= 1 }
  }

  mutating func goNext() {
    if canNext { index += 1 }
  }

  @MainActor
  static func load(language: String, repository: AzkarRepository) throws -> StandingCursor {
    let chapters = try GuideCatalog.load(language: language, repository: repository)
    guard let chapter = chapters.first(where: { $0.categoryID == 16 }), !chapter.lines.isEmpty else {
      throw CocoaError(.fileNoSuchFile)
    }
    return StandingCursor(
      categoryID: chapter.categoryID,
      posture: chapter.posture,
      lines: chapter.lines,
      index: 0
    )
  }
}

struct GuideView: View {
  @EnvironmentObject private var store: AzkarStore
  @Environment(\.dismiss) private var dismiss
  @AppStorage("accent") private var accent = "brown"
  @State private var cursor: StandingCursor?
  @State private var showSheet = false

  var body: some View {
    ZStack {
      Image("GuideStanding")
        .resizable()
        .scaledToFill()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()
        .accessibilityIdentifier("guide.posture.standing")
    }
    .overlay {
      GeometryReader { geometry in
        if let cursor {
          Text(store.language == "ar" ? cursor.line.arabic : cursor.line.translated)
            .font(AppAppearance.font(size: 17))
            .multilineTextAlignment(.center)
            .lineLimit(4)
            .padding(16)
            .frame(width: min(geometry.size.width * 0.86, 420))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.72)
            .accessibilityIdentifier("guide.bubble")
            .accessibilityValue(cursor.accessibilityValue)
        }
      }
      .allowsHitTesting(false)
    }
    .overlay(alignment: .bottom) {
      if let cursor {
        HStack(spacing: 16) {
          Button(text("Back", "رجوع")) { goBack() }
            .frame(minWidth: 44, minHeight: 44)
            .disabled(!cursor.canBack)
            .accessibilityIdentifier("guide.back")
          Button(text("Open", "افتح")) { showSheet = true }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("guide.expand")
          Button(AppCopy.text("Next")) { goNext() }
            .frame(minWidth: 44, minHeight: 44)
            .disabled(!cursor.canNext)
            .accessibilityIdentifier("guide.next")
        }
        .font(AppAppearance.font(size: 17, bold: true))
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
      }
    }
    .overlay(alignment: .topLeading) {
      Button(AppCopy.text("Close")) { dismiss() }
        .font(AppAppearance.font(size: 17, bold: true))
        .frame(minWidth: 44, minHeight: 44)
        .padding(20)
        .accessibilityIdentifier("guide.close")
    }
    .sheet(isPresented: $showSheet) {
      if let cursor {
        VStack(alignment: .leading, spacing: 16) {
          Text(text("Hisn line", "حصن"))
            .font(AppAppearance.font(size: 15, bold: true))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("guide.sheet")
          Text(cursor.line.arabic)
            .font(AppAppearance.font(size: 20))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("guide.sheet.arabic")
          Text(cursor.line.translated)
            .font(AppAppearance.font(size: 17))
            .foregroundStyle(.secondary)
          Text("\(cursor.line.repeatCount)")
            .font(AppAppearance.font(size: 17, bold: true))
            .accessibilityIdentifier("guide.sheet.repeat")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDragIndicator(.visible)
      }
    }
    .tint(AppAppearance.accent(accent))
    .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
    .task {
      cursor = try? StandingCursor.load(language: store.language, repository: store.repository)
    }
  }

  private func goBack() {
    guard var current = cursor else { return }
    current.goBack()
    cursor = current
  }

  private func goNext() {
    guard var current = cursor else { return }
    current.goNext()
    cursor = current
  }

  private func text(_ english: String, _ arabic: String) -> String {
    store.language == "ar" ? arabic : english
  }
}
