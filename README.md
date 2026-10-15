# SVG Cleaner

Native macOS app (SwiftUI) to optimize SVGs in bulk with SVGO. Rebuild of the Glaze version, without Glaze or Node at runtime.

## How it works

- UI in SwiftUI (macOS 26+, Apple silicon).
- SVGO 3.3.3 is bundled as a single script (`Resources/svgo.js`) and runs in Apple's JavaScriptCore.
- Previews render with WebKit, so they match what a browser shows.
- Settings are stored in UserDefaults (`nl.cube.svgcleaner`).

## Build and install

```sh
./build.sh               # builds build/SVG Cleaner.app and installs it in ~/Applications
./build.sh --no-install  # build only
```

Requires Xcode (or the Command Line Tools). Node is only needed to rebuild `svgo.js`:

```sh
cd vendor && npm install && npm run build
```

## Layout

- `Sources/SVGCleaner/` app code (models, SVGO bridge, views)
- `Resources/` Info.plist, app icon, bundled SVGO
- `vendor/` npm setup that produces `Resources/svgo.js`
