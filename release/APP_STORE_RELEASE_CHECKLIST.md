# App Store Connect & release checklist (automated bits are in repo; you still confirm these manually)

Things **already wired in the project**:

- Google **UMP** runs before ads initialize (`AdsManager`): consent form when required by region.
- `RequestConfiguration`: max rating **G**, child-directed and under-age signals set to **false** (change in `AdsManager._initialize_mobile_ads` if you truly target minors).
- **Privacy Policy** and **Terms of Use** are bundled as `legal/privacy_policy.txt` and `legal/terms_of_use.txt` and open in-game via **`PrivacyTermsPopup`** (Remove Ads → Privacy Policy / Terms of Use). Optionally set **`ComplianceConfig.APP_STORE_PRIVACY_POLICY_URL`** to your hosted HTTPS duplicate for App Store Connect only (same text as `legal/privacy_policy.txt`).
- iOS export preset **`NSUserTrackingUsageDescription`** via **Additional plist content** (needed because the Poing AdMob plugin links App Tracking Transparency). Edit the wording in **`export_presets.cfg`** → `application/additional_plist_content` if you want different copy.

## You complete in App Store Connect (cannot be scripted from Godot)

1. **Privacy Policy URL** — App Store Connect still requires an HTTPS URL. Paste the hosted copy of **`legal/privacy_policy.txt`** (matching wording): **https://musecast.github.io/frogquest/privacy_policy.html**. Players can also read the bundled policy in-app.

2. **App Privacy questionnaire** — answer truthfully for your build (ads, IAP, analytics, Firebase/AdMob, crash tools, etc.). Match what SDKs collect; adjust if you add/remove SDKs.

3. **Support URL** — set in App Store Connect as needed for your storefront listing (website, ticketing, etc.).

4. **Age rating / kids** — align with COPPA/Google child-directed declarations; if aimed at kids, change UMP/request flags accordingly and follow kids policies.

## Production ad & IAP identifiers

Live iOS AdMob identifiers are wired in **`scripts/AdsManager.gd`**, **`export_presets.cfg`** (`plugins_plist/GADApplicationIdentifier`), and the bundled iOS AdMob plugin plist.

Ensure **Remove Ads** product id `com.muse.frogquest.removeads` matches App Store Connect and is cleared for sale.

## Remove Ads IAP submission

App Store Connect status **Missing Metadata** usually means the product still needs review metadata, most commonly the **Review Information → Screenshot** field. For `com.muse.frogquest.removeads`:

- Product ID: `com.muse.frogquest.removeads`
- Reference Name: `Remove Ads`
- Localization display name: `Remove Ads`
- Localization description: `Remove Ads!`
- Review screenshot: upload a screenshot that shows the in-game Remove Ads screen / buy button. This is for Apple's review, not the optional App Store Promotion image.
- Review notes suggestion: `Non-consumable Remove Ads purchase. Launch the app, open the pause/settings menu, then tap Remove Ads. The product ID is com.muse.frogquest.removeads. Purchase removes integrated banner and interstitial ads. Restore Purchases is available on the same screen. No login is required.`

For the first in-app purchase, Apple requires it to be submitted with a new app version: after the binary is uploaded, go to the app version page and add `Remove Ads` in **In-App Purchases and Subscriptions** before submitting the version to App Review.

The Godot code expects the iOS StoreKit singleton `InAppStore` (or a compatible `InAppPurchase` singleton). Before the final iPhone build, make sure an iOS IAP plugin is installed and enabled in the iOS export preset; otherwise the Remove Ads buttons stay disabled in-game even though App Store Connect has the product.

Before uploading, run this from the project root on the machine that has Godot:

```sh
Godot --headless --path . --script res://tools/validate_app_store_release.gd
```

Do not upload while it reports any **BLOCKER**. The current repo has the live iOS AdMob app ID, banner unit, interstitial unit, and hosted privacy policy URL wired.

`ComplianceConfig.APP_STORE_PRIVACY_POLICY_URL` is set to the hosted policy URL above. App Store Connect still needs that same public HTTPS URL pasted into the app metadata.

For the App Privacy answers, include the data collected by Google AdMob and Apple purchases. Apple says third-party partner data must be included in App Store Connect privacy answers, and Google's current AdMob iOS disclosure says the Mobile Ads SDK may collect device IDs, advertising data, IP address/general location signals, diagnostics, and ad interaction/performance data. Recheck the final answers against your exact enabled SDKs and consent settings.

## Review / smoke passes (recommended)

Cold launch → playable level; **pause/resume/settings** portrait and landscape; **Remove Ads** / restore; **Privacy Policy** and **Terms of Use** buttons open bundled in-app text; gameplay with banner; **rotation** mid-game; endless **game over** + restart + exit.

After first production ad build on device, verify real fills and revenue in AdMob; test ATT prompt behavior if personalization depends on consent + tracking.

If **headless**/`--export` fails loading `res://scenes/Main.tscn` around an embedded `TileSetAtlasSource` line, open `Main.tscn` in the Godot 4.6 editor and **save** the scene once so large embedded resources can be migrated to the current text format (same project, no gameplay change required).
