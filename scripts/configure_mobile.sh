#!/usr/bin/env bash
set -euo pipefail

if [[ -f android/app/src/main/AndroidManifest.xml ]]; then
  python3 - <<'PY'
from pathlib import Path
p=Path('android/app/src/main/AndroidManifest.xml')
s=p.read_text()
if 'xmlns:tools=' not in s:
    s=s.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">','<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools">')
perms='''\n    <uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.WAKE_LOCK"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>'''
if 'android.permission.WAKE_LOCK' not in s:
    s=s.replace('>', '>'+perms, 1)
s=s.replace('android:name=".MainActivity"','android:name="com.ryanheise.audioservice.AudioServiceActivity"')
service='''\n        <service android:name="com.ryanheise.audioservice.AudioService" android:foregroundServiceType="mediaPlayback" android:exported="true" tools:ignore="Instantiatable">\n            <intent-filter><action android:name="android.media.browse.MediaBrowserService" /></intent-filter>\n        </service>\n        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver" android:exported="true" tools:ignore="Instantiatable">\n            <intent-filter><action android:name="android.intent.action.MEDIA_BUTTON" /></intent-filter>\n        </receiver>'''
if 'com.ryanheise.audioservice.AudioService"' not in s:
    s=s.replace('</application>',service+'\n    </application>')
p.write_text(s)
PY
fi

if [[ -f ios/Runner/Info.plist ]]; then
  python3 - <<'PY'
from pathlib import Path
p=Path('ios/Runner/Info.plist')
s=p.read_text()
if '<key>UIBackgroundModes</key>' not in s:
    s=s.replace('</dict>', '  <key>UIBackgroundModes</key>\n  <array>\n    <string>audio</string>\n  </array>\n</dict>')
p.write_text(s)
PY
fi
