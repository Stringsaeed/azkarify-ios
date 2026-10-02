import SwiftUI

/// A searchable country selector shared by the setup sheet and prayer
/// settings. CountryKit/API data stays in LocationCatalogStore; this view
/// only owns presentation and selection.
struct CountrySelectionSheet: View {
  @EnvironmentObject private var store: AzkarStore
  @EnvironmentObject private var locationCatalog: LocationCatalogStore
  @Environment(\.dismiss) private var dismiss
  @AppStorage("accent") private var accent = "brown"

  let selectedCountryCode: String
  let onSelect: (PrayerCountry) -> Void

  @State private var search = ""

  private var arabic: Bool { store.language == "ar" }

  private func text(_ english: String, _ arabic: String) -> String {
    self.arabic ? arabic : english
  }

  private var filteredCountries: [PrayerCountry] {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return locationCatalog.countries }

    return locationCatalog.countries.filter { country in
      country.code.localizedCaseInsensitiveContains(query)
        || country.englishName.localizedCaseInsensitiveContains(query)
        || country.arabicName.localizedCaseInsensitiveContains(query)
    }
  }

  var body: some View {
    NavigationStack {
      Group {
        if locationCatalog.countriesLoading && locationCatalog.countries.isEmpty {
          ProgressView(text("Loading countries…", "جارٍ تحميل الدول…"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if locationCatalog.countriesError != nil,
          locationCatalog.countries.isEmpty
        {
          ContentUnavailableView(
            text("Could not load countries", "تعذر تحميل الدول"),
            systemImage: "globe",
            description: Text(text(
              "Try again to load the country list.",
              "حاول مرة أخرى لتحميل قائمة الدول.")))
          Button(text("Retry", "إعادة المحاولة")) {
            Task { await locationCatalog.loadCountries(language: store.language, forceRefresh: true) }
          }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("country.retry")
        } else {
          List {
            if let _ = locationCatalog.countriesError {
              Section {
                catalogRetryRow
              }
            }

            if locationCatalog.countriesLoading {
              Section {
                ProgressView(text("Refreshing countries…", "جارٍ تحديث الدول…"))
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .listRowBackground(Color.clear)
              }
            }

            ForEach(filteredCountries) { country in
              Button {
                onSelect(country)
                dismiss()
              } label: {
                HStack(spacing: 12) {
                  VStack(alignment: .leading, spacing: 2) {
                    Text(country.name(language: store.language))
                    Text(country.code)
                      .font(AppAppearance.font(size: 12))
                      .foregroundStyle(.secondary)
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)

                  if selectedCountryCode.caseInsensitiveCompare(country.code) == .orderedSame {
                    Image(systemName: "checkmark")
                      .fontWeight(.semibold)
                      .foregroundStyle(AppAppearance.accent(accent))
                      .accessibilityLabel(text("Selected", "محدد"))
                  }
                }
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityIdentifier("country.\(country.code)")
            }

            if filteredCountries.isEmpty {
              ContentUnavailableView(
                text("No matching countries", "لا توجد دول مطابقة"),
                systemImage: "magnifyingglass")
            }
          }
          .listStyle(.plain)
        }
      }
      .font(AppAppearance.font(size: 17))
      .searchable(
        text: $search,
        placement: .navigationBarDrawer(displayMode: .always),
        prompt: text("Search countries", "ابحث عن دولة"))
      .accessibilityIdentifier("country.search")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Label(text("Back", "رجوع"), systemImage: "chevron.backward")
          }
          .accessibilityIdentifier("country.back")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(text("Done", "تم")) { dismiss() }
            .accessibilityIdentifier("country.done")
        }
      }
      .navigationTitle(text("Choose a country", "اختر دولة"))
      .navigationBarTitleDisplayMode(.inline)
    }
    .environment(\.layoutDirection, arabic ? .rightToLeft : .leftToRight)
    .task {
      await locationCatalog.loadCountries(language: store.language)
    }
  }

  private var catalogRetryRow: some View {
    HStack(spacing: 10) {
      Text(text(
        "Some countries may be unavailable. Try again to refresh.",
        "قد لا تتوفر بعض الدول. حاول مرة أخرى للتحديث."))
        .font(AppAppearance.font(size: 13))
        .foregroundStyle(.secondary)
      Spacer(minLength: 8)
      Button(text("Retry", "إعادة المحاولة")) {
        Task { await locationCatalog.loadCountries(language: store.language, forceRefresh: true) }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .accessibilityIdentifier("country.retry")
    }
    .listRowBackground(Color.clear)
  }
}
