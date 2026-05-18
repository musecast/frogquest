# App Store Connect & release checklist (automated bits are in repo; you still confirm these manually)

Things **already wired in the project**:

- Google **UMP** runs before ads initialize (`AdsManager`): consent form when required by region.
- `RequestConfiguration`: max rating **G**, child-directed and under-age signals set to **false** (change in `AdsManager._initialize_mobile_ads` if you truly target minors).
- **Privacy Policy** and **Terms of Use** are bundled as `legal/privacy_policy.txt` and `legal/terms_of_use.txt` and open in-game via **`PrivacyTermsPopup`** (Remove Ads → Privacy Policy / Terms of Use). Optionally set **`ComplianceConfig.APP_STORE_PRIVACY_POLICY_URL`** to your hosted HTTPS duplicate for App Store Connect only (same text as `legal/privacy_policy.txt`).
- iOS export preset **`NSUserTrackingUsageDescription`** via **Additional plist content** (needed because the Poing AdMob plugin links App Tracking Transparency). Edit the wording in **`export_presets.cfg`** → `application/additional_plist_content` if you want different copy.

## You complete in App Store Connect (cannot be scripted from Godot)

1. **Privacy Policy URL** — App Store Connect still requires an HTTPS URL. Paste the hosted copy of **`legal/privacy_policy.txt`** (matching wording); store the URL in **`ComplianceConfig.APP_STORE_PRIVACY_POLICY_URL`** if you ever need to open it from tooling. Players always read policy in-app from the bundled file.

2. **App Privacy questionnaire** — answer truthfully for your build (ads, IAP, analytics, Firebase/AdMob, crash tools, etc.). Match what SDKs collect; adjust if you add/remove SDKs.

3. **Support URL** — set in App Store Connect as needed for your storefront listing (website, ticketing, etc.).

4. **Age rating / kids** — align with COPPA/Google child-directed declarations; if aimed at kids, change UMP/request flags accordingly and follow kids policies.

## Production ad & IAP identifiers

Replace Google **demo** AdMob IDs in **`scripts/AdsManager.gd`** and **`export_presets.cfg`** (`plugins_plist/GADApplicationIdentifier`) with **your live** app ID and ad units before shipping.

Ensure **Remove Ads** product id `com.muse.frogquest.removeads` matches App Store Connect and is cleared for sale.

Before uploading, run this from the project root on the machine that has Godot:

```sh
Godot --headless --path . --script res://tools/validate_app_store_release.gd
```

Do not upload while it reports any **BLOCKER**. As of the current repo state, the expected blockers are:

- `plugins_plist/GADApplicationIdentifier` is still Google's sample AdMob app ID.
- `scripts/AdsManager.gd` still uses Google's sample banner ad unit.
- `scripts/AdsManager.gd` still uses Google's sample interstitial ad unit.

The validator also warns if `ComplianceConfig.APP_STORE_PRIVACY_POLICY_URL` is blank. App Store Connect requires a public HTTPS privacy policy URL even though the policy is also bundled in-game.

For the App Privacy answers, include the data collected by Google AdMob and Apple purchases. Apple says third-party partner data must be included in App Store Connect privacy answers, and Google's current AdMob iOS disclosure says the Mobile Ads SDK may collect device IDs, advertising data, IP address/general location signals, diagnostics, and ad interaction/performance data. Recheck the final answers against your exact enabled SDKs and consent settings.

## Review / smoke passes (recommended)

Cold launch → playable level; **pause/resume/settings** portrait and landscape; **Remove Ads** / restore; **Privacy Policy** and **Terms of Use** buttons open bundled in-app text; gameplay with banner; **rotation** mid-game; endless **game over** + restart + exit.

After first production ad build on device, verify real fills and revenue in AdMob; test ATT prompt behavior if personalization depends on consent + tracking.

If **headless**/`--export` fails loading `res://scenes/Main.tscn` around an embedded `TileSetAtlasSource` line, open `Main.tscn` in the Godot 4.6 editor and **save** the scene once so large embedded resources can be migrated to the current text format (same project, no gameplay change required).
