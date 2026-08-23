# 1940sRadio

A cross-platform 1940s-inspired internet radio application, with **Fog Point Radio** as its featured station.

## Build 0.1.0

Build 0.1 establishes the first playable receiver and the Linux packaging pipeline.

### Included

- Fog Point Radio direct stream: `https://streaming.live365.com/a25002`
- Real stream playback using `media_kit`
- Power on/off control
- Adjustable volume control
- Signal/connection/error states with retry
- 1940s tabletop-radio inspired wood cabinet
- Cloth speaker grille treatment
- Illuminated tuning glass and animated tuning needle
- Six-station preset bank UI, with Fog Point occupying preset 1 for this build
- Responsive layout groundwork for later desktop and mobile targets
- Linux x86_64 AppImage CI artifact

The station/preset system is intentionally structured so later builds can add arbitrary internet radio URLs rather than making this a Fog Point-only player.

## Linux AppImage

GitHub Actions builds the Linux version on pushes to `build-0.1` and on version tags.

The workflow:

1. Installs the current stable Flutter toolchain.
2. Generates the Linux Flutter runner.
3. Resolves dependencies.
4. Runs `flutter analyze`.
5. Builds a release-mode Linux bundle.
6. Packages it as `1940sRadio-0.1.0-x86_64.AppImage` using linuxdeploy and appimagetool.
7. Uploads the AppImage as a GitHub Actions artifact.

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
bash scripts/package_appimage.sh 0.1.0
```

The generated AppImage is placed under:

```text
build/appimage/out/
```

## Planned targets

The application architecture is intended to grow into:

- Linux (AppImage)
- Windows
- macOS
- Android
- iOS

Future builds will add editable stations, functional presets, station metadata, saved favorites, mobile background playback, media controls, and deeper period-radio interaction.
