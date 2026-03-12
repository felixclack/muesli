---
name: muesli-meeting-history
description: Reads Muesli meeting history and transcripts from local session storage. Use when a user asks to inspect past meetings, review transcripts, search recorded calls, summarize recent meetings, or load transcript text from the Muesli app's stored sessions.
---

<examples>
<example>
Context: The user wants a quick list of recorded meetings.
user: "Show me my recent Muesli meetings"
assistant: "I'll use the muesli-meeting-history skill to enumerate your saved Muesli sessions before I summarize anything."
</example>
<example>
Context: The user wants content from a specific transcript.
user: "Read the transcript from yesterday's design sync"
assistant: "I'll use the muesli-meeting-history skill to find the matching session and load its transcript text."
</example>
<example>
Context: The user wants to search across several meeting transcripts.
user: "Find every meeting where we discussed Gather support"
assistant: "I'll use the muesli-meeting-history skill to list the stored sessions first, then load the relevant transcripts and search them."
</example>
</examples>

Use this skill when working with recordings created by Muesli. The on-disk source of truth is:

`~/Library/Application Support/Muesli/Meetings/`

Each session folder may contain:

- `metadata.json`
- `transcript.txt`
- `segments.json`
- `system.m4a`
- `mic.m4a`
- `mix.m4a`

## Workflow

1. Start with the helper script instead of hand-rolling `find` + `jq` pipelines:

```bash
python3 scripts/meeting_history.py --format json --limit 25
```

2. Use that output to identify the relevant sessions by `id`, title, date, or transcript presence.

3. Only load transcript text for the sessions you actually need. For a single session:

```bash
python3 scripts/meeting_history.py --format json --session-id <SESSION_ID> --include-transcripts --transcript-chars 0
```

4. If the user explicitly asks for all transcripts or a cross-meeting search, it is okay to load more broadly:

```bash
python3 scripts/meeting_history.py --format json --limit 0 --include-transcripts --transcript-chars 0
```

5. Keep context lean. Prefer listing sessions first, then reading only the matching transcripts, unless the user clearly asks for a full export.

## Useful Flags

- `--limit 25`: return the 25 most recent sessions. Use `0` for no limit.
- `--match gather`: case-insensitive substring filter across title, provider, URL, and folder path.
- `--session-id <ID>`: load one exact session.
- `--has-transcript`: only return sessions that already have a transcript.
- `--include-transcripts`: include transcript text in the output.
- `--transcript-chars 4000`: cap transcript text length. Use `0` for the full transcript.
- `--format json`: best for reliable agent parsing.

## Output Guidance

- When summarizing, mention which sessions had transcripts and which did not.
- Use the stored session metadata as the canonical source for dates, provider, and file paths.
- If a transcript is missing, say that clearly instead of implying the meeting was not recorded.
- If you need the raw file after finding a session, use the `transcriptPath` or `storageFolderPath` returned by the script.
