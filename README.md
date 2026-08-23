# 1940sRadio

A cross-platform 1940s-inspired internet radio application, with **Fog Point Radio** as its featured station.

## Build 0.2.0

Build 0.2 turns the first Fog Point receiver into a persistent general-purpose internet radio while keeping the physical 1940s tabletop-radio presentation.

### Included

- Fog Point Radio built in as the featured/default station: `https://streaming.live365.com/a25002`
- Real stream playback using `media_kit`
- Power on/off and adjustable volume controls
- Signal/connection/error states with retry
- Frameless transparent desktop window: visually, the application is just the radio cabinet
- No operating-system title bar on Linux, Windows, or macOS
- Position-lock/pin button built into the radio
  - pin off: drag the radio using decorative/non-control areas
  - pin on: radio position is locked
- In-radio minimize and close buttons for desktop
- Persistent station directory
- Add arbitrary `http://` or `https://` direct stream URLs
- Edit and remove user-added stations
- Current station name/subtitle shown on the illuminated dial
- Tuning needle moves as saved stations change
- Six persistent user-assignable presets
  - click an assigned preset to tune
  - click an empty preset to store the current station
  - hold a preset to replace it with the current station
  - right-click a preset to clear it
- Fog Point starts in preset 1 by default
- Responsive radio layout groundwork for desktop and future mobile targets
- Linux x86_64 AppImage CI artifact and GitHub Release packaging

## Linux AppImage

GitHub Actions builds the Linux version on pushes to `build-0.2`, pull requests into `main`, and pushes to `main`.

The workflow:

1. Installs the current stable Flutter toolchain.
2. Generates the Linux Flutter runner.
3. Resolves dependencies.
4. Runs `flutter analyze lib`.
5. Builds a release-mode Linux bundle.
6. Packages it as `1940sRadio-0.2.0-x86_64.AppImage` using linuxdeploy and appimagetool.
7. Uploads the AppImage as a GitHub Actions artifact.
8. On `main`, publishes the AppImage in the `v0.2.0` GitHub Release.

## Local development

Install Flutter with Linux desktop support, then run:

```bash
flutter create . --platforms=linux --org com.huhman416 --project-name radio1940s
flutter pub get
flutter run -d linux
```

For a local release build:

```bash
flutter build linux --release
bash scripts/package_appimage.sh 0.2.0
```

The generated AppImage is placed under:

```text
build/appimage/out/
```

## Planned targets

The shared Flutter application architecture targets:

- Linux (AppImage)
- Windows
- macOS
- Android
- iOS

Later builds can add stream metadata/now-playing information, favorites, expanded tuner behavior, mobile background playback and lock-screen controls, alarms/sleep timers, and deeper period-radio interaction.
