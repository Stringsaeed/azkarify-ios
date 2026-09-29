# Azkarify iOS

Open `azkarify.xcodeproj` in Xcode. The app uses SwiftData to cache the Hisn index and category entries, and Swift Package Manager for RevenueCat.

The app configures RevenueCat at launch with its Apple public SDK key. Update that key in `azkarify/Services/RevenueCatService.swift` if the RevenueCat app changes. Configure a current offering and paywall in RevenueCat for the Settings support button to show it.

App Store purchases require the In-App Purchase capability, a matching App Store Connect bundle ID, and store product setup. The app currently uses `com.stringsaeed.azkarify`.

## Local text editor

The Arabic and English datasets are checked into `content/`. To edit text, line breaks, category titles, and repetition counts:

```sh
python3 content-editor/server.py
```

Open http://127.0.0.1:8765 and click **Save changes** to write edits back to JSON. See [the editor guide](content-editor/README.md) for details. The iOS app's data loading is unchanged; switching it to bundled JSON is a separate step.
