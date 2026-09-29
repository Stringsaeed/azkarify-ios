# Azkarify iOS

Open `azkarify.xcodeproj` in Xcode. The app reads its Arabic and English Hisn indexes and entries from bundled JSON in `content/`, with no content network requests or SwiftData cache. Swift Package Manager provides RevenueCat.

The app configures RevenueCat at launch with its Apple public SDK key. Update that key in `azkarify/Services/RevenueCatService.swift` if the RevenueCat app changes. Configure a current offering and paywall in RevenueCat for the Settings support button to show it.

App Store purchases require the In-App Purchase capability, a matching App Store Connect bundle ID, and store product setup. The app currently uses `com.stringsaeed.azkarify`.

## Local text editor

The Arabic and English datasets are checked into `content/`. To edit text, line breaks, category titles, and repetition counts:

```sh
python3 content-editor/server.py
```

Open http://127.0.0.1:8765 and click **Save changes** to write edits back to JSON. See [the editor guide](content-editor/README.md) for details. Xcode copies this same folder into the app bundle, preserving the language directories. Rebuild the app after editing JSON to include the changes. Reading azkar works offline from first launch; purchases still use RevenueCat.
