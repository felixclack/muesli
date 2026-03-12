#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_BASE_DIR = Path.home() / "Library/Application Support/Muesli/Meetings"


@dataclass
class SessionRecord:
    raw: dict[str, Any]
    sort_date: datetime


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Read Muesli meeting history and transcript files."
    )
    parser.add_argument(
        "--base-dir",
        default=str(DEFAULT_BASE_DIR),
        help="Root directory for Muesli meeting storage.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=25,
        help="Maximum number of sessions to return. Use 0 for no limit.",
    )
    parser.add_argument(
        "--match",
        default=None,
        help="Case-insensitive substring filter across title, provider, URL, and folder path.",
    )
    parser.add_argument(
        "--session-id",
        default=None,
        help="Exact Muesli session UUID to load.",
    )
    parser.add_argument(
        "--has-transcript",
        action="store_true",
        help="Only include sessions that already have transcript.txt metadata.",
    )
    parser.add_argument(
        "--include-transcripts",
        action="store_true",
        help="Embed transcript text in the output.",
    )
    parser.add_argument(
        "--transcript-chars",
        type=int,
        default=4000,
        help="Maximum transcript characters to include when --include-transcripts is set. Use 0 for full text.",
    )
    parser.add_argument(
        "--format",
        choices=("json", "text"),
        default="text",
        help="Output format.",
    )
    return parser.parse_args()


def parse_timestamp(value: str | None) -> datetime:
    if not value:
        return datetime(1970, 1, 1, tzinfo=timezone.utc)
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def load_sessions(base_dir: Path) -> list[SessionRecord]:
    if not base_dir.exists():
        return []

    records: list[SessionRecord] = []
    for metadata_path in base_dir.rglob("metadata.json"):
        try:
            raw = json.loads(metadata_path.read_text(encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001
            print(
                f"warning: failed to parse {metadata_path}: {exc}",
                file=sys.stderr,
            )
            continue

        transcript = raw.get("transcript") or {}
        transcript_path = transcript.get("transcriptPath")
        storage_folder_path = raw.get("storageFolderPath")
        raw["metadataPath"] = str(metadata_path)
        raw["transcriptPath"] = transcript_path
        raw["segmentsPath"] = transcript.get("segmentsPath")
        raw["transcriptAvailable"] = bool(transcript_path and Path(transcript_path).exists())
        raw["storageFolderPath"] = storage_folder_path

        sort_date = parse_timestamp(raw.get("startedAt") or raw.get("scheduledStart"))
        records.append(SessionRecord(raw=raw, sort_date=sort_date))

    records.sort(key=lambda record: record.sort_date, reverse=True)
    return records


def matches(record: dict[str, Any], args: argparse.Namespace) -> bool:
    if args.session_id and record.get("id") != args.session_id:
        return False

    if args.has_transcript and not record.get("transcriptAvailable"):
        return False

    if args.match:
        haystack = " ".join(
            str(record.get(field) or "")
            for field in ("title", "provider", "canonicalMeetingURL", "storageFolderPath")
        ).lower()
        if args.match.lower() not in haystack:
            return False

    return True


def maybe_attach_transcript(record: dict[str, Any], max_chars: int) -> None:
    transcript_path = record.get("transcriptPath")
    if not transcript_path:
        record["transcriptText"] = None
        return

    path = Path(transcript_path)
    if not path.exists():
        record["transcriptText"] = None
        return

    text = path.read_text(encoding="utf-8")
    if max_chars > 0:
        record["transcriptText"] = text[:max_chars]
        record["transcriptTruncated"] = len(text) > max_chars
    else:
        record["transcriptText"] = text
        record["transcriptTruncated"] = False


def to_output_record(record: dict[str, Any], include_transcripts: bool, max_chars: int) -> dict[str, Any]:
    output = {
        "id": record.get("id"),
        "title": record.get("title"),
        "provider": record.get("provider"),
        "state": record.get("state"),
        "startedAt": record.get("startedAt"),
        "endedAt": record.get("endedAt"),
        "scheduledStart": record.get("scheduledStart"),
        "scheduledEnd": record.get("scheduledEnd"),
        "canonicalMeetingURL": record.get("canonicalMeetingURL"),
        "interrupted": record.get("interrupted"),
        "errorMessage": record.get("errorMessage"),
        "storageFolderPath": record.get("storageFolderPath"),
        "metadataPath": record.get("metadataPath"),
        "transcriptPath": record.get("transcriptPath"),
        "segmentsPath": record.get("segmentsPath"),
        "transcriptAvailable": record.get("transcriptAvailable"),
    }

    if include_transcripts:
        maybe_attach_transcript(record, max_chars)
        output["transcriptText"] = record.get("transcriptText")
        output["transcriptTruncated"] = record.get("transcriptTruncated", False)

    return output


def render_text(records: list[dict[str, Any]], include_transcripts: bool) -> str:
    if not records:
        return "No Muesli meetings found."

    chunks: list[str] = []
    for record in records:
        lines = [
            f"{record.get('title') or '(Untitled meeting)'}",
            f"  id: {record.get('id')}",
            f"  provider: {record.get('provider')}",
            f"  state: {record.get('state')}",
            f"  started: {record.get('startedAt') or record.get('scheduledStart')}",
            f"  transcript: {record.get('transcriptPath') or 'missing'}",
            f"  folder: {record.get('storageFolderPath')}",
        ]
        if include_transcripts:
            transcript_text = record.get("transcriptText")
            if transcript_text:
                lines.append("  transcript_text:")
                for line in transcript_text.splitlines():
                    lines.append(f"    {line}")
            else:
                lines.append("  transcript_text: missing")
        chunks.append("\n".join(lines))
    return "\n\n".join(chunks)


def main() -> int:
    args = parse_args()
    base_dir = Path(args.base_dir).expanduser()
    sessions = load_sessions(base_dir)
    filtered = [record.raw for record in sessions if matches(record.raw, args)]

    if args.limit > 0:
        filtered = filtered[: args.limit]

    output_records = [
        to_output_record(record, args.include_transcripts, args.transcript_chars)
        for record in filtered
    ]

    if args.format == "json":
        payload = {
            "baseDir": str(base_dir),
            "count": len(output_records),
            "sessions": output_records,
        }
        print(json.dumps(payload, indent=2))
    else:
        print(render_text(output_records, args.include_transcripts))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
