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

If you want to try it on another Mac, start from the latest release and expect a one-time manual Gatekeeper bypass until notarization is added.
