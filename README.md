# Muesli

Muesli is a native macOS menu bar app that watches your synced macOS calendars for Google Meet and Gather links, records meeting audio automatically, and generates local transcripts with Whisper.

V1 is intentionally small:

- audio only
- local-first
- no backend
- no speaker diarization
- no summaries

## What It Does

- Scans Calendar events for supported meeting links in the event URL, location, or notes
- Arms meetings 15 minutes before their scheduled start and keeps them eligible for 2 hours after the scheduled end
- Auto-starts recording when it detects that you have joined a supported meeting
- Captures both system audio and microphone audio
- Mixes the final recording and transcribes it locally with Whisper
- Stores recordings, transcripts, and metadata on disk so you can reopen or retry later

## Supported Providers

- Google Meet in Dia
- Gather via the Gather desktop app

Google Meet in Dia is the primary supported path in V1. Gather support is best-effort and uses app activity plus recent audio activity heuristics.

## Requirements

- macOS 15 or newer
- A local macOS Calendar setup with your calendars already synced into the Calendar app
- Dia installed if you use Google Meet there
- Gather installed if you use Gather

## Installation

Download the latest build from [GitHub Releases](https://github.com/felixclack/muesli/releases).

The easiest installer is the DMG:

1. Download `Muesli-*-macOS-universal.dmg`.
2. Open the DMG.
3. Drag `Muesli.app` into `Applications`.
4. Launch `Muesli.app`.

This project is not notarized yet, so macOS may block the first launch on another machine. If that happens:

1. Open `Applications`.
2. Right-click `Muesli.app`.
3. Choose `Open`.
4. Confirm the prompt.

For local reinstalls, macOS permissions are most likely to persist when:

- the app stays at `/Applications/Muesli.app`
- the bundle identifier stays `com.felixclack.muesli`
- each reinstall is signed with the same non-ad-hoc certificate

Ad hoc local builds often look like a different app to macOS privacy controls, so Screen Recording, Microphone, Calendar, and Automation prompts may reappear after reinstalling.

## First-Run Setup

On first launch, Muesli needs a few macOS permissions:

- Calendar Full Access
- Screen Recording
- Microphone
- Automation access for Dia

It will also download the local English Whisper model on demand.

You can review and re-run setup from the Settings window.

## How It Works

1. Muesli reads upcoming events from EventKit.
2. It extracts supported meeting links from each event.
3. It arms meetings inside the active detection window.
4. It polls Dia tabs for Google Meet or the Gather app for Gather meetings.
5. When a meeting is considered joined, it starts recording:
   - `system.m4a`
   - `mic.m4a`
6. When the meeting ends, it creates `mix.m4a`.
7. Whisper runs locally and writes:
   - `transcript.txt`
   - `segments.json`

Only one automatic recording runs at a time. If multiple meetings appear live at once, Muesli enters a conflict state instead of starting two recordings.

## Where Files Are Stored

Muesli keeps session data under:

`~/Library/Application Support/Muesli/Meetings/`

Each session folder contains files like:

- `metadata.json`
- `system.m4a`
- `mic.m4a`
- `mix.m4a`
- `transcript.txt`
- `segments.json`

The Whisper model is stored at:

`~/Library/Application Support/Muesli/Models/ggml-small.en.bin`

## Current Limitations

- Audio only. There is no video capture.
- Transcription is English-only in the current setup.
- There is no diarization or speaker labeling yet.
- Gather detection is heuristic and less reliable than Meet in Dia.
- Muesli records system output audio while a meeting is active, so notification sounds or unrelated audio may be captured.
- The app is currently distributed as a direct download, not a notarized build.

## Development

This repo includes a checked-in Xcode project and a `project.yml` for XcodeGen.

### Build

```bash
xcodebuild -project Muesli.xcodeproj -scheme Muesli -destination 'platform=macOS' build
```

### Test

```bash
xcodebuild -project Muesli.xcodeproj -scheme Muesli -destination 'platform=macOS' test
```

### Regenerate The Xcode Project

If you change `project.yml`, regenerate the project with XcodeGen:

```bash
xcodegen generate
```

### Fastlane Release Setup

This repo now uses Fastlane for local reinstalls, Developer ID certificate setup, and signed/notarized releases.

The wrapper scripts prefer a globally installed `fastlane`, but they now fall back to `bundle exec fastlane` automatically when only the Bundler-managed gem is available.

Check the current machine state first:

```bash
fastlane mac doctor
```

Fastlane will use these defaults unless you override them:

- bundle identifier: `com.felixclack.muesli`
- team ID: `4754Y2K7H2`

For App Store Connect authentication, set one of:

- `APP_STORE_CONNECT_API_KEY_PATH` to a Fastlane-compatible API key JSON file
- `FASTLANE_USER` to your Apple ID email

If you use `FASTLANE_USER` for notarization, also set:

- `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD`

To keep API keys out of git, a convenient place is `fastlane/credentials/`, which is ignored by `.gitignore`.

For a local-only setup on this Mac, you can also keep Fastlane secrets in `.env.fastlane`. The wrapper scripts load that file automatically if it exists.

### Create Or Sync The Developer ID Certificate

If you want Fastlane to manage the `Developer ID Application` certificate for you, create a private GitHub repo at `felixclack/muesli-certificates`. Fastlane now assumes that repository by default:

```bash
FASTLANE_TEAM_ID="4754Y2K7H2" \
APP_STORE_CONNECT_API_KEY_PATH="fastlane/credentials/AuthKey_ABC123XYZ.json" \
scripts/setup_signing.sh
```

That lane first tries to sync an existing `Developer ID Application` certificate from `git@github.com:felixclack/muesli-certificates.git` into your local keychain.

If the private certificates repo does not have one yet, the first `Developer ID Application` certificate may still need to be created manually by the Apple Developer Account Holder using a CSR. After that first certificate is imported into Keychain and stored in `match`, future `setup_signing` runs can sync it automatically.

If you want to use a different private certificates repo later, override it with `MATCH_GIT_URL`.

If you already have a `Developer ID Application` certificate installed locally, you can skip `setup_signing` and go straight to `release`.

### Reinstall Locally Without Changing App Identity

Build and reinstall a clean release copy into `/Applications`:

```bash
scripts/reinstall_local_app.sh
```

If you want macOS permissions to have the best chance of persisting between reinstalls, provide the same signing identity every time. `local_install` now prefers `Developer ID Application` automatically when one is available so the local app matches the notarized release identity more closely:

```bash
MUESLI_INSTALL_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
scripts/reinstall_local_app.sh
```

`Apple Distribution` and `Apple Development` still work as fallbacks if you need them, but they are less ideal for matching the shipped direct-download build.

If this Mac does not have any Apple-issued signing identities, you can create a stable self-signed identity once and then reuse it for local permission testing:

```bash
scripts/setup_local_signing.sh
scripts/reinstall_local_app.sh
```

That local identity defaults to `Muesli Local Development` and is stored in `~/Library/Keychains/muesli-local-signing.keychain-db`. It is only for repeatable local installs; notarized releases should still use `Developer ID Application`.

### Signed And Notarized Releases

The release lane builds the app, re-signs it with a `Developer ID Application` certificate, notarizes the app and DMG, staples the results, and writes DMG/ZIP artifacts plus SHA-256 checksums to `build/release-artifacts/`:

```bash
APP_STORE_CONNECT_API_KEY_PATH="fastlane/credentials/AuthKey_ABC123XYZ.json" \
scripts/release_macos.sh
```

If you prefer Apple ID authentication instead of an API key:

```bash
FASTLANE_USER="you@example.com" \
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
scripts/release_macos.sh
```

The lane auto-detects the first `Developer ID Application` identity in your keychain. You can override it explicitly:

```bash
MUESLI_RELEASE_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
APP_STORE_CONNECT_API_KEY_PATH="fastlane/credentials/AuthKey_ABC123XYZ.json" \
scripts/release_macos.sh
```

### GitHub Actions Releases

The repo also supports running the notarized macOS release on GitHub Actions via `.github/workflows/release.yml`.

Add these repository secrets first:

- `APPLE_DEVELOPER_ID_CERTIFICATE_P12_BASE64`: base64-encoded `Developer ID Application` `.p12`
- `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`: password used when exporting that `.p12`
- `CI_KEYCHAIN_PASSWORD`: random password for the temporary CI keychain
- `APP_STORE_CONNECT_API_KEY_JSON`: the full Fastlane-compatible App Store Connect API key JSON

To export the certificate from a Mac that already has the signing identity:

```bash
security export -k ~/Library/Keychains/login.keychain-db \
  -t identities \
  -f pkcs12 \
  -P "your-export-password" \
  -o fastlane/credentials/muesli-developer-id.p12

base64 < fastlane/credentials/muesli-developer-id.p12 | pbcopy
```

The workflow supports two modes:

- `workflow_dispatch` to release a chosen ref manually
- `push` on tags matching `v*`

Manual dispatch defaults to the current `CFBundleShortVersionString` in `Muesli/Info.plist`, so the usual flow is:

1. Bump the app version in git.
2. Push that commit to GitHub.
3. Run the `Release macOS` workflow against that ref.

Each run executes `fastlane mac doctor`, the full `xcodebuild` test suite, `fastlane mac release`, uploads the DMG and ZIP as workflow artifacts, and then creates or updates the matching GitHub release.

## Tech Stack

- SwiftUI for the menu bar app and windows
- AppKit where native macOS integration is needed
- EventKit for calendar access
- ScreenCaptureKit for system audio and microphone capture
- AVFoundation for audio processing
- whisper.cpp via Swift Package Manager for local transcription

## Status

This is a V1 intended to get the core flow working end to end on a real Mac setup. The current focus is:

- reliable Meet detection in Dia
- workable Gather support
- solid local audio capture
- recoverable transcription jobs

If you want to try it on another Mac, start from the latest notarized release.
