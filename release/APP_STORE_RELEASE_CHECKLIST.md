# App Store Connect & release checklist (automated bits are in repo; you still confirm these manually)

Things **already wired in the project**:

- Google **UMP** runs before ads initialize (`AdsManager`): consent form when required by region, then the IDFA explainer and Apple's tracking (ATT) prompt once the AdMob IDFA message is published (see below). The consent timeout leaves a showing form alone, so ads start after the player answers.
- `RequestConfiguration`: max rating **T** (teen), child-directed and under-age signals set to **false** (change in `AdsManager._initialize_mobile_ads` if you truly target minors). T lets far more advertisers bid than G did; the App Store age rating has to cover it (13+, below).
- **Rewarded ads**: Endless mode offers one "KEEP GOING (WATCH AD)" revive per run after a fall (`game_over_screen.gd` → `AdsManager.show_rewarded`). Remove Ads owners get "KEEP GOING" with no ad.
- **Privacy Policy** and **Terms of Use** are bundled as `legal/privacy_policy.txt` and `legal/terms_of_use.txt` and open in-game via **`PrivacyTermsPopup`** (Remove Ads → Privacy Policy / Terms of Use). Optionally set **`ComplianceConfig.APP_STORE_PRIVACY_POLICY_URL`** to your hosted HTTPS duplicate for App Store Connect only (same text as `legal/privacy_policy.txt`).
- iOS export preset includes `NSUserTrackingUsageDescription` in **Additional plist content**, declares tracking (`privacy/tracking_enabled=true`), and marks device ID and advertising data as used for tracking.

**Current ATT decision:** Frog Quest+ asks for tracking so ads can be targeted. The prompt comes from Google's UMP SDK, which only shows it after an **IDFA explainer message** is published for this app in AdMob. Apple has already asked why a build with `NSUserTrackingUsageDescription` showed no prompt, so **do not upload until a fresh install shows the prompt** (step 1 under ATT below).

## You complete in App Store Connect (cannot be scripted from Godot)

1. **Privacy Policy URL** — App Store Connect still requires an HTTPS URL. Paste the hosted copy of **`legal/privacy_policy.txt`** (matching wording): **https://jasonmuse.github.io/frog-quest-support/privacy_policy.html**. Players can also read the bundled policy in-app.

2. **App Privacy questionnaire** — answer truthfully for your build (ads, IAP, analytics, Firebase/AdMob, crash tools, etc.). Match what SDKs collect; adjust if you add/remove SDKs.

3. **Support URL** — use the hosted support page: **https://jasonmuse.github.io/frog-quest-support/support.html**.

4. **Marketing URL / developer website** — use **https://jasonmuse.github.io/frog-quest-support/**.

4. **Age rating / kids**: **done for 1.1.** The content answers are all None/No (Advertising: Yes; the newer Social Media questions: No), so Apple calculates 4+. **Override to Higher Age Rating → 13+** covers the T-rated ads, and Apple requires ads to fit the app's age rating. It shows as 13+ in 172 countries, 12+ in Brazil and Vietnam, and 12+ on iOS versions before 26. It goes live with version 1.1. Korea's "Add RCN" only matters if Korea's game rating board requires a classification number. Align with COPPA/Google child-directed declarations; if aimed at kids, change UMP/request flags (and drop the ad rating back to G) and follow kids policies.

## Production ad & IAP identifiers

Live iOS AdMob identifiers are wired in **`scripts/AdsManager.gd`**, **`export_presets.cfg`** (`plugins_plist/GADApplicationIdentifier`), and the bundled iOS AdMob plugin plist.

Before expecting reliable live ad fill, finish these AdMob-side items:

- **Privacy & messaging**: the **IDFA explainer is published** ("Frog Quest+ IDFA explainer", Google's standard English text, Frog Quest+ only). It's what makes the tracking prompt appear; AdMob says allow up to an hour. Still to do: AdMob shows no European regulations (GDPR) or US state regulations message for the account yet. Without the GDPR one, players in the EEA, UK and Switzerland only get limited (lower-paying) ads. If device logs say `Failed to read publisher's account configuration`, the in-app SDK ran but AdMob does not have the matching form/config ready yet.
- **Rewarded ad unit**: done. **FQrewarded** (Rewarded, 1 Revive, no partner bidding) is `ca-app-pub-3776793413956253/4063431642`, in `REWARDED_ID` in `scripts/AdsManager.gd`. Rewarded units take video and interactive/playable creatives by default. New units can take up to an hour to start serving.
- **Interstitial ad unit**: in AdMob, make sure the interstitial unit allows video and rich media too, so playable and video ads can compete for it.
- **app-ads.txt / app readiness**: after the App Store listing has a developer website, publish AdMob's `app-ads.txt` snippet at that site's root and request/check verification in AdMob. New AdMob apps may have limited serving until app verification and readiness review finish.
- **No fill**: `Request Error: No ad to show` means the request reached AdMob but no ad was returned. It is not a Godot scene crash; retest after AdMob approval/verification and on a stable device network.

Ensure **Remove Ads** product id `com.muse.frogquest.removeads` matches App Store Connect and is cleared for sale.

## Remove Ads IAP submission

App Store Connect status **Missing Metadata** usually means the product still needs review metadata, most commonly the **Review Information → Screenshot** field. For `com.muse.frogquest.removeads`:

- Product ID: `com.muse.frogquest.removeads`
- Reference Name: `Remove Ads`
- Localization display name: `Remove Ads`
- Localization description: `Remove Ads!`
- Review screenshot: upload a screenshot that shows the in-game Remove Ads screen / buy button. This is for Apple's review, not the optional App Store Promotion image.
- Review notes suggestion: `Non-consumable Remove Ads purchase. Launch the app, open the pause/settings menu, then tap Remove Ads. The product ID is com.muse.frogquest.removeads. Purchase removes integrated banner and interstitial ads. Restore Purchases is available on the same screen. No login is required.`

**Version**: 1.0 is live. **1.1 (build 6)** was uploaded to TestFlight on Nov 1, 2026 by the GitHub workflow below. Version 1.1 exists in App Store Connect (Prepare for Submission). The Godot 4.7 template already sets `ITSAppUsesNonExemptEncryption = NO`, so TestFlight builds skip the export-compliance question.

## Uploading to TestFlight without a Mac (GitHub Actions)

GitHub builds on its own Mac machines (free, because the repo is public): **github.com/musecast/frogquest → Actions → TestFlight → Run workflow**. It takes about 3 minutes: Godot 4.7.1 exports the Xcode project, Xcode 26 archives it, and it's signed and uploaded. Apple then needs 5–30 minutes to process the build before it appears in TestFlight.

- **Build numbers** are automatic: one above the highest build already in App Store Connect. The version (1.1) comes from the iOS export preset, so bump `application/short_version` there for 1.2. If you ever upload from a Mac instead, use a build number above the last one the workflow uploaded.
- **Secrets** (repo Settings → Secrets and variables → Actions): `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, from the App Store Connect API key **"Github Testflight"** (Team key, Admin). The workflow's first step checks them with Apple before building and says which one is wrong.
- **Signing**: Xcode's own App Store Connect sign-in rejects API keys on GitHub's Macs ("Cannot verify client's JWT headers"). So `tools/ci/asc_signing.py` makes an Apple Distribution certificate and an App Store profile named **"Frog Quest CI cert …"** through the API, signs with them in a throwaway keychain, and `altool` uploads. A failed run revokes its certificate at once; a successful run's certificate is revoked at the start of the next run. If a run says the team is at its certificate limit, revoke an unused distribution certificate at developer.apple.com.
- **Testers**: the internal TestFlight group **"Muse"** has automatic distribution on, so every processed build goes straight to the TestFlight app for the people in it.
- **Xcode 27.1 / iPhone Duo**: the workflow runs on GitHub's `xcode-27` machine with Xcode 27.1, because only apps linked against the **iOS 27.1 SDK** reach the edges of iPhone Duo's inner display. Builds from older SDKs run in a smaller window in the middle (1.0 does), and iOS 27.0 SDK builds leave a strip by the status bar. The inner display ignores supported orientations, and the cover display is a normal iPhone. Story mode no longer forces landscape (`Main.gd` uses `SCREEN_SENSOR`, like Endless), so the portrait layouts and camera apply there.

For the first in-app purchase, Apple requires it to be submitted with a new app version: after the binary is uploaded, go to the app version page and add `Remove Ads` in **In-App Purchases and Subscriptions** before submitting the version to App Review.

The Godot code now supports the installed StoreKit 2 plugin singleton `IOSInAppPurchase`, plus older `InAppStore` / `InAppPurchase` fallbacks. The iOS IAP plugin lives at `ios/plugins/ios-in-app-purchase/ios-in-app-purchase.gdip` and is enabled in the iOS export preset as `plugins/IOSInAppPurchase=true`.

**iOS plugins are tied to the Godot version.** The project is on Godot **4.7.1**, so `ios/plugins` holds the 4.7 builds: the IAP plugin is **v0.4.0** (hrk4649/godot_ios_plugin_iap, "for Godot 4.7"; v0.3.0 was the 4.6 build) and the AdMob libraries come from **`poing-godot-admob-ios-v4.7.1.zip`** in the AdMob plugin's v4.3.1 release. Our `.gdip` files were kept: the download's `poing-godot-admob-ads.gdip` carries Google's *test* app ID. After any Godot upgrade, swap both again before exporting for iOS, or the app can fail to link or crash. The 4.7.1 iOS export template is installed in `%APPDATA%\Godot\export_templates\4.7.1.stable\ios.zip`.

**Exporting from the command line:** the AdMob exporter patches `project.pbxproj` with the Google Mobile Ads Swift package in a *deferred* step, and a `--headless --export-release` run quits before it happens. After a headless export, run `PbxprojService.patch(<pbxproj>, "PoingGodotAdMobDepsPackage")` (see the log for "AdMob: Patched project.pbxproj"), or export from the editor window, where it runs on its own. Without it Xcode can't find the `GAD…` symbols.

On the final iPhone/TestFlight build, open Remove Ads and confirm the buy/restore buttons are enabled. In the device log you should see `AdsManager: purchase backend detected: IOSInAppPurchase`. If the screen still says store purchases are not configured, stop and re-check that the iOS export preset has the `IOSInAppPurchase` plugin checked.

Before uploading, run this from the project root on the machine that has Godot:

```sh
Godot --headless --path . --script res://tools/validate_app_store_release.gd
Godot --headless --path . --script res://tools/validate_level.gd
Godot --headless --path . --script res://tools/validate_layout_fit.gd
Godot --headless --path . --script res://tools/validate_endless.gd
```

Do not upload while it reports any **BLOCKER**. `validate_level` fails after the level's been painted until `tools/thin_tilemap_collision.gd` is run again: buried wall tiles carry no collision, and the drop shadow hidden under solid wall is parked in a switched-off layer, so the world loads fast and light on a phone. `validate_layout_fit` fails if any menu runs off any screen shape or under a banner, or any button or label's words are cut off, or the pixel font is drawn anywhere but a whole step of its 16-pixel grid (16, 32, 48...), 1:1 (or a whole number of times with nearest filtering), with a one-pixel outline: `UIStyle.px` and `UIStyle.outline_px` give those. Every menu, settings and the privacy policy included, has to stay clear of both ad banners: they're drawn over the game, so anything under one can't be tapped. `validate_endless` climbs Endless from the pond to space and fails if a gap can't be jumped, a zone is missing, or springs, crumbling platforms or "keep going" stop working. The current repo has the live iOS AdMob app ID, banner unit, interstitial unit, and hosted privacy policy URL wired.

`ComplianceConfig.APP_STORE_PRIVACY_POLICY_URL` is set to the hosted policy URL above. App Store Connect still needs that same public HTTPS URL pasted into the app metadata.

For the App Privacy answers, include the data collected by Google AdMob and Apple purchases. Apple says third-party partner data must be included in App Store Connect privacy answers, and Google's current AdMob iOS disclosure says the Mobile Ads SDK may collect device IDs, advertising data, IP address/general location signals, diagnostics, and ad interaction/performance data. Recheck the final answers against your exact enabled SDKs and consent settings.

### ATT / tracking (targeted ads)

Frog Quest requests App Tracking Transparency permission through Google's UMP SDK so AdMob can serve targeted ads to players who allow it.

1. **Confirm the prompt before every upload**: delete the app (or reset Settings → Privacy & Security → Tracking), install the build, launch it, and check that the IDFA explainer appears followed by Apple's "Allow … to track your activity" alert. No alert means the AdMob IDFA message isn't published yet. Fix that before uploading, or App Review will reject the build again.
2. **App Privacy answers**: **done and published.** **Device ID** and **Advertising Data** are marked **used for tracking**, so the label now has "Data Used to Track You: Identifiers, Usage Data". The rest was already declared, linked but not tracking: Purchase History, Product Interaction, Coarse Location, Performance Data, Crash Data. Recheck it if you add or remove SDKs. The Godot export privacy settings match: `privacy/tracking_enabled=true`, with `device_id` and `advertising_data` marked `used_for_tracking=true`.
3. **Review notes**: you can add "Frog Quest shows Apple's App Tracking Transparency prompt on first launch, after a short explainer, before any ads load."
4. **Muse account (to do before the next App Store submission)**: the optional sign-in sends the player's email to the Muse account service. In App Privacy add **Contact Info → Email Address**: App Functionality, linked to the user, not used for tracking (the export preset already declares it: `privacy/collected_data/email_address`). In the review notes say sign-in is optional, uses an existing Muse account (made in Muse Shelf), and only adds Frog Quest+ for Muse Pro members (the + on the logo, no ads); the whole game plays without it, and Remove Ads is sold in the app.

Players who tap **Ask App Not to Track** still get ads, just not targeted ones. The privacy policy already covers advertising identifiers "subject to consent" and the iOS Tracking setting.

## Review / smoke passes (recommended)

Cold launch → playable level; **pause/resume/settings** portrait and landscape; **Remove Ads** buy/restore buttons enabled; sandbox purchase applies ad-free state; restore re-applies ad-free state after resetting local data; **Privacy Policy** and **Terms of Use** buttons open bundled in-app text; gameplay with banner; **rotation** mid-game; endless **game over** + restart + exit.

After first production ad build on device, verify real fills and revenue in AdMob; test ATT prompt behavior if personalization depends on consent + tracking.

If **headless**/`--export` fails loading `res://scenes/Main.tscn` around an embedded `TileSetAtlasSource` line, open `Main.tscn` in the Godot 4.6 editor and **save** the scene once so large embedded resources can be migrated to the current text format (same project, no gameplay change required).
