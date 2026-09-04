# 1940sRadio

A cross-platform 1940s-inspired internet radio application, with **Fog Point Radio** as its featured station.

## Build 0.5 — The Receiver Update

Build 0.5 turns the project from a themed stream player into a more complete desktop receiver while preserving the physical 1940s tabletop-radio presentation.

### Featured signal

Fog Point Radio now uses the current Radio.co direct stream:

```text
https://s4.radio.co/s3ff272827/listen
```

The app also checks a small built-in-station manifest hosted with the repository. If Fog Point moves again, the manifest can update its primary/fallback endpoint without requiring a full application release; the compiled-in Radio.co URL remains the offline fallback.

### Receiver features

- Real stream playback using `media_kit`
- Responsive full-cabinet and compact-receiver layouts
- Slider-based station tuning designed for mouse and future touch use
- Tuning static and optional radio-atmosphere modes: Off, Subtle, Period
- Tube warm-up behavior and animated signal/tuning eye
- Persistent power-adjacent receiver state, volume, station selection, presets, favorites, lamp, window placement and compact mode
- Six physical/mechanical station presets
- Favorites kept separate from presets
- Custom direct HTTP/HTTPS station directory
- `TEST SIGNAL` check before saving a custom stream
- Best-effort ICY Now Playing information and recent listening history
- Automatic reconnect with bounded backoff and support for fallback station endpoints
- Sleep timer with final-minute volume fade
- Wake alarm with selectable days, wake station, wake volume and optional gentle tube warm-up
- Receiver configuration import/export (`.json`)
- Frameless transparent desktop cabinet
- Position lock/pin and restored desktop position/size
- Desktop tray controls for show, power, volume, presets and graceful quit
- Close/hide-to-tray behavior plus a separate real Quit path
- Ordered media shutdown before window destruction to avoid the earlier Linux/manual-close teardown crash
- Android/iOS background media-control groundwork remains in the shared Flutter codebase

## Linux downloads

Build 0.5 intentionally ships in **two forms**.

### Portable AppImage

`1940sRadio-0.5.0-x86_64.AppImage`

Use this when you want to try the application, keep it portable, or do not want a normal installation. Mark it executable and run it directly.

### Installable desktop archive

`1940sRadio-0.5.0-Linux-x86_64.tar.gz`

Extract the archive and run:

```bash
./install.sh
```

The installer is per-user and does not require `sudo`. It installs the release bundle under:

```text
~/.local/share/radio1940s/
```

and creates:

- a normal desktop/application-menu launcher
- `~/.local/bin/radio1940s`
- `~/.local/bin/uninstall-radio1940s`

To uninstall:

```bash
uninstall-radio1940s
```

Receiver preferences are intentionally left in the platform preferences store so reinstalling does not erase station/preset configuration.

## Local Linux development

Install Flutter with Linux desktop support and the required native packages (GTK, MPV/GStreamer, and AppIndicator development files), then run:

```bash
flutter create . --platforms=linux --org com.huhman416 --project-name radio1940s
bash scripts/configure_linux_transparency.sh
flutter pub get
flutter run -d linux
```

For a release build:

```bash
flutter build linux --release
```

Create the portable AppImage:

```bash
bash scripts/package_appimage.sh 0.5.0
```

Create the installable desktop archive:

```bash
bash scripts/package_linux_installer.sh 0.5.0
```

Or install the local release bundle directly for the current user:

```bash
bash scripts/install_linux.sh
```

## Targets

The shared Flutter codebase targets:

- Linux — primary desktop target; AppImage + installable desktop archive
- Windows — shared desktop receiver groundwork
- macOS — shared desktop receiver groundwork
- Android — background playback/media controls groundwork
- iOS — background playback/media controls groundwork
