# Azkarify iOS

Open `azkarify.xcodeproj` in Xcode. The app uses SwiftData to cache the Hisn index and category entries, and Swift Package Manager for RevenueCat.

The app configures RevenueCat at launch with its Apple public SDK key. Update that key in `azkarify/Services/RevenueCatService.swift` if the RevenueCat app changes. Configure a current offering and paywall in RevenueCat for the Settings support button to show it.

App Store purchases require the In-App Purchase capability, a matching App Store Connect bundle ID, and store product setup. The app currently uses `com.stringsaeed.azkarify`.
