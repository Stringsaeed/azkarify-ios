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
    guard canBack else { return }
    index -= 1
  }

  mutating func goNext() {
    guard canNext else { return }
    index += 1
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
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("guide.posture.standing")
    }
    .overlay(alignment: .bottom) {
      if let cursor {
        Text(store.language == "ar" ? cursor.line.arabic : cursor.line.translated)
          .font(AppAppearance.font(size: 17))
          .foregroundStyle(.primary)
          .multilineTextAlignment(.center)
          .lineLimit(4)
          .padding(16)
          .frame(maxWidth: .infinity)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
          .accessibilityIdentifier("guide.bubble")
          .accessibilityValue(cursor.accessibilityValue)
          .padding(.horizontal, 20)
          .padding(.bottom, 88)
          .allowsHitTesting(false)
      }
    }
    .overlay(alignment: .bottom) {
      if let cursor {
        HStack {
          guideButton(text("Back", "رجوع"), identifier: "guide.back", enabled: cursor.canBack) {
            goBack()
          }
          Spacer()
          guideButton(AppCopy.text("Next"), identifier: "guide.next", enabled: cursor.canNext) {
            goNext()
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
      }
    }
    .overlay(alignment: .top) {
      HStack {
        guideButton(AppCopy.text("Close"), identifier: "guide.close") {
          dismiss()
        }
        Spacer()
        if cursor != nil {
          guideButton(text("Open", "افتح"), identifier: "guide.expand") {
            showSheet = true
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)
    }
    .sheet(isPresented: $showSheet) {
      sheet
    }
    .tint(AppAppearance.accent(accent))
    .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
    .task {
      guard cursor == nil else { return }
      cursor = try? StandingCursor.load(language: store.language, repository: store.repository)
    }
  }

  private var sheet: some View {
    ZStack(alignment: .topLeading) {
      AppAppearance.background(accent)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cursor?.accessibilityValue ?? " ")
        .accessibilityIdentifier("guide.sheet")
      if let cursor {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            Text(cursor.line.arabic)
              .font(AppAppearance.font(size: 20))
              .frame(maxWidth: .infinity, alignment: .leading)
              .accessibilityIdentifier("guide.sheet.arabic")
            Text(cursor.line.translated)
              .font(AppAppearance.font(size: 17))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(cursor.line.repeatCount)")
              .font(AppAppearance.font(size: 17, bold: true))
              .accessibilityIdentifier("guide.sheet.repeat")
          }
          .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityElement(children: .contain)
    .presentationDragIndicator(.visible)
  }

  private func guideButton(
    _ title: String, identifier: String, enabled: Bool = true, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .font(AppAppearance.font(size: 17, bold: true))
        .frame(minWidth: 44, minHeight: 44)
    }
    .buttonStyle(.bordered)
    .disabled(!enabled)
    .accessibilityIdentifier(identifier)
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
