# Azkarify iOS

## Countries API connection

The app uses [Stringsaeed/countries-api](https://github.com/Stringsaeed/countries-api). The checked-in [OpenAPI snapshot](docs/location-catalog.openapi.json) comes from server commit `14b7686307e6c6bd3a10abc4f8f887b2bf9f0987`. It replaces the earlier proposed static-file contract. [Country](docs/location-catalog-examples/countries.json) and [city](docs/location-catalog-examples/AE-cities.json) examples illustrate the new response shape.

| Build | Catalog base URL | App Attest environment |
| --- | --- | --- |
| Debug | `https://staging.api.saeed.sh/v1` | `development` |
| Release | `https://staging.api.saeed.sh/v1` | `production` |

Both builds intentionally use staging for now. Release retains production App Attest because distributed builds use that environment; the staging server accepts both development and production attestations. Switching to production later requires changing the Release catalog URL.

`LOCATION_CATALOG_BASE_URL` and `APP_ATTEST_ENVIRONMENT` are Xcode build settings expanded through `Config/Info.plist` and `Config/azkarify.entitlements`. Data endpoints are relative to the base URL. Enrollment uses `auth/challenge` and `auth/attest` under the same `/v1` base.

Every network data request uses Apple App Attest, including ETag revalidation. The client serializes requests so Apple assertion counters reach the server in order. It signs the complete encoded HTTPS URL, `Accept-Language`, `If-None-Match`, and a fresh challenge. Redirects are rejected because they change the signed URL. There is no API token or anonymous production fallback. The server's [iOS authentication protocol](https://github.com/Stringsaeed/countries-api/blob/main/docs/ios-authentication.md) is authoritative.

App Attest requires a supported physical device. Simulator and unsupported-device builds use cached or bundled data. Enable App Attest for the explicit Apple App ID, regenerate the provisioning profile, and confirm the profile contains `com.apple.developer.devicecheck.appattest-environment`. The server must use the registered App ID prefix and bundle ID `com.stringsaeed.azkarify`. The prefix is not necessarily the Team ID, so verify it in the Apple Developer account.

Countries are fetched with pagination. Cities are downloaded one page at a time, with server-side English/Arabic search and a Load more action. City search requires 2–64 characters and at most five words. Coordinates use the response's `location` object, timezone uses `timezone`, and calculation methods use the server's snake_case names. Missing Arabic names fall back to English. A null calculation-method recommendation uses the app's Muslim World League default, which remains editable in prayer settings.

The app keeps a private disk cache for offline use. Cache entries and ETags are separated by API environment, language, country, and query. Fresh entries last 24 hours. Each expired entry requires a new App Attest challenge and assertion before a conditional request. Dataset changes invalidate old pagination cursors; the client restarts the result set instead of mixing versions.

The API receives the selected country code, search text, display language, and App Attest proof. Device GPS coordinates, journey progress, and points are never uploaded. Device location and prayer calculations remain on the phone.

### Physical-device verification

1. Deploy staging and configure its Apple identifiers to match the signing profile.
2. Run a Debug build on a supported physical iPhone with the development App Attest entitlement.
3. Open location setup, search for a country, and search for a city. Verify enrollment succeeds and city pages load.
4. Load another page, switch languages, and relaunch to verify cached data and key reuse.
5. Verify offline cached access and an ETag `304` after revalidation.
6. Before release, test the production endpoint with a production-signed build. Simulator tests cannot certify Apple's attestation or server certificate-chain verification.

## App setup

Open `azkarify.xcodeproj` in Xcode. The app reads its Arabic and English Hisn indexes and entries from bundled JSON in `content/`, with no content network requests or SwiftData cache. Swift Package Manager provides RevenueCat.

The app configures RevenueCat at launch with its Apple public SDK key. Update that key in `azkarify/Services/RevenueCatService.swift` if the RevenueCat app changes. Configure a current offering and paywall in RevenueCat for the Settings support button to show it.

App Store purchases require the In-App Purchase capability, a matching App Store Connect bundle ID, and store product setup. The app currently uses `com.stringsaeed.azkarify`.

## Local text editor

The Arabic and English datasets are checked into `content/`. To edit text, line breaks, category titles, and repetition counts:

```sh
python3 content-editor/server.py
```

Open http://127.0.0.1:8765 and click **Save changes** to write edits back to JSON. See [the editor guide](content-editor/README.md) for details. Xcode copies this same folder into the app bundle, preserving the language directories. Rebuild the app after editing JSON to include the changes. Reading azkar works offline from first launch; purchases still use RevenueCat.
