# PurePaste

PurePaste is a simple menu bar app for macOS that cleans common tracking parameters from URLs you copy.

It helps often, but not always. Some links still need manual cleanup. That is why the app has a **Pause** button.

## Where to find releases

Download the latest DMG from the GitHub releases page:
- https://github.com/jayf0x/Pure-Paste/releases

If you build locally, the installer is created at:
- `./PurePaste.dmg`

## How it works

PurePaste watches your clipboard while active.

When you copy a URL:
- it checks if the URL has known tracking parameters,
- removes matching parameters,
- writes the cleaned URL back to the clipboard,
- increments a global counter of removed parameters.

Rules are based on these sources:
- `https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy-removeparam.txt`
- `https://gitlab.com/ClearURLs/rules/-/raw/master/data.min.json`

The app uses a pre-parsed rules file:
- `assets/parsedRules.json`

In the app menu:
- **Pause / Activate** controls clipboard monitoring.
- **Options > Refetch rules** reloads the latest `parsedRules.json` from the repo URL.
- **Options > Reset counter** resets the global removed-parameter counter.

## Limitations

- It is not a security tool.
- It may miss some trackers or break edge-case URLs.
- Background rule fetch may fail (network, rate limits, etc.).
- Clipboard automation behavior can differ per app/site.

## For nerds

- Build installer:
  - `./scripts/build-dmg.sh`
- Create release draft:
  - `./scripts/release.sh`
- Persistent app state (last cleaned URL + global counter):
  - `~/Library/Application Support/PurePaste/state.json`
- Rules cache:
  - `~/Library/Caches/PurePaste/parsedRules.json`
- Rules URL override env var:
  - `PUREPASTE_RULES_URL`
