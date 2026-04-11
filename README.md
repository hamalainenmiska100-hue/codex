# Codex

A minimal iOS wrapper app for `https://chatgpt.com/codex/cloud` using SwiftUI + `WKWebView`.

## Included

- Full Xcode project (`Codex.xcodeproj`)
- Shared scheme (`Codex`)
- SwiftUI app target
- `WKWebView` wrapper
- Full-size page rendering via `pageZoom = 1.0`
- Back/forward swipe gestures
- All normal web links stay inside the app
- Persistent web data inside the app using `WKWebsiteDataStore.default()`
- Light haptics for interactive page taps
- Initial reveal only after the page `load` event fires
- GitHub Actions workflow that builds an unsigned `.ipa`
- Local shell script that does the same archive + unsigned IPA packaging

## Important note about login persistence

Login will persist inside this app across launches because the app uses the persistent default `WKWebsiteDataStore`.

That does not guarantee reuse of the login state from the Safari app itself. If you are not already logged in inside this wrapper app, you may need to log in once here.

## Bundle identifier

The project currently uses:

`com.miskangrwm.Codex`

Change it later if you want a different identifier before signing/distributing.

## Local build on a Mac

```bash
./scripts/build_unsigned_ipa.sh
```

Output:

```text
build/Codex-unsigned.ipa
```

## GitHub Actions

The workflow lives here:

```text
.github/workflows/build-unsigned-ipa.yml
```

It produces two artifacts:

- `Codex-unsigned-ipa`
- `Codex-xcarchive`

## Signing later

This project archives with signing disabled and then packages the `.app` from the archive into an unsigned `.ipa`.
