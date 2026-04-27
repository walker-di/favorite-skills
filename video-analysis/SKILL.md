---
name: video-analysis
description: Analyze and understand video files with Gemini 3.1 Flash Lite Preview via terminal cURL. Use when the user asks to summarize, inspect, extract scenes/timestamps/actions, critique, audit, or answer questions about a video.
compatibility: Requires GEMINI_API_KEY, curl, jq, and local video files or a downloaded copy of a public video.
---

# Video Analysis — Gemini 3.1 Flash Lite Preview via cURL

Use this skill when the user wants to understand a video: summarize it, identify scenes, extract timestamps, describe actions/objects/speech, critique content, compare against requirements, or answer questions grounded in video evidence.

Default model: `gemini-3.1-flash-lite-preview`.
Default API: `streamGenerateContent`.
Default thinking: `MINIMAL`.
Default tool: `googleSearch` enabled for external/contextual grounding when useful.

> Note: pi skill names must use lowercase letters/numbers/hyphens, so the installable skill id is `video-analysis` even if the user says `video_analysis`.

## Prerequisites

- `GEMINI_API_KEY` must be exported in the shell.
- `curl` and `jq` must be available.
- For local video files, the skill uploads the video through the Gemini Files API, waits until the file is active, then calls `streamGenerateContent`.
- For web videos, first obtain a local file when legally/technically allowed (for example with `yt-dlp`), then analyze that file. If download is not possible, ask the user for the video file or transcript.

Quick check:

```bash
: "${GEMINI_API_KEY:?Set GEMINI_API_KEY first}"
command -v curl
command -v jq
```

## Output hygiene

For every analysis, create or use a dedicated output folder:

```bash
artifacts/video-analysis/YYYY-MM-DD-short-slug/
```

Save at minimum:

- `prompt.md` — the exact analysis prompt.
- `request.json` — the exact Gemini request payload.
- `file.json` — the uploaded file metadata.
- `response.json` — raw streaming API response.
- `analysis.md` — extracted text answer.
- a copy/symlink note for the source video path when appropriate.

Do not overwrite prior analyses. Use numbered or slugged output folders.

## First ask / clarify

If the user's request is underspecified, ask only for the missing essentials:

1. **Video input**: local path, uploaded file path, or downloadable URL.
2. **Goal**: summary, timestamped scene breakdown, QA, safety/moderation, UX/design critique, bug reproduction, marketing critique, transcript-oriented extraction, etc.
3. **Granularity**: high-level summary vs. timestamp-by-timestamp details.
4. **Output format**: bullets, table, JSON, issue list, storyboard, test observations.

If the user provides enough context, proceed without over-questioning and state assumptions.

## Recommended analysis prompt

Use a precise prompt that requests evidence and prevents hallucinated timestamps:

```text
Analyze the attached video.

Goal: <user goal>

Return:
1. Executive summary in 3-5 bullets.
2. Timestamped scene/action breakdown. Use approximate timestamps only when visible/inferable from the video; mark uncertain timestamps as approximate.
3. Important visual details: people, objects, UI states, text visible on screen, transitions, anomalies.
4. Audio/speech notes if present and understandable.
5. Direct answer to the user's question.
6. Uncertainties / missing evidence.

Rules:
- Ground every claim in visible or audible evidence from the video.
- Do not invent exact timestamps, dialogue, UI text, or off-screen context.
- If using Google Search for background context, clearly separate searched context from video evidence.
```

## Fast path: use bundled script

From any working directory:

```bash
/Users/walker/.pi/agent/skills/video-analysis/scripts/analyze-video.sh \
  /path/to/video.mp4 \
  "Summarize the video and provide a timestamped scene breakdown." \
  artifacts/video-analysis/$(date +%F)-short-slug
```

Then read `analysis.md` and inspect `response.json` if the extracted text looks incomplete.

## Manual cURL workflow

Use this when you need to customize the request or debug the API.

### 1) Prepare workspace

```bash
set -e -Euo pipefail

: "${GEMINI_API_KEY:?Set GEMINI_API_KEY first}"
MODEL_ID="${GEMINI_MODEL_ID:-gemini-3.1-flash-lite-preview}"
GENERATE_CONTENT_API="streamGenerateContent"
VIDEO_PATH="/path/to/video.mp4"
OUTDIR="artifacts/video-analysis/$(date +%F)-short-slug"
mkdir -p "$OUTDIR"

MIME_TYPE="$(file -b --mime-type "$VIDEO_PATH")"
NUM_BYTES="$(wc -c < "$VIDEO_PATH" | tr -d ' ')"
DISPLAY_NAME="$(basename "$VIDEO_PATH")"
```

### 2) Upload the video with the Files API

```bash
curl -sS \
  "https://generativelanguage.googleapis.com/upload/v1beta/files?key=${GEMINI_API_KEY}" \
  -D "$OUTDIR/upload-headers.txt" \
  -H "X-Goog-Upload-Protocol: resumable" \
  -H "X-Goog-Upload-Command: start" \
  -H "X-Goog-Upload-Header-Content-Length: ${NUM_BYTES}" \
  -H "X-Goog-Upload-Header-Content-Type: ${MIME_TYPE}" \
  -H "Content-Type: application/json" \
  -d "{\"file\":{\"display_name\":\"${DISPLAY_NAME}\"}}" \
  > "$OUTDIR/upload-start.json"

UPLOAD_URL="$(grep -i '^x-goog-upload-url:' "$OUTDIR/upload-headers.txt" | cut -d' ' -f2- | tr -d '\r')"

curl -sS "$UPLOAD_URL" \
  -H "Content-Length: ${NUM_BYTES}" \
  -H "X-Goog-Upload-Offset: 0" \
  -H "X-Goog-Upload-Command: upload, finalize" \
  --data-binary "@${VIDEO_PATH}" \
  > "$OUTDIR/file.json"

FILE_URI="$(jq -r '.file.uri' "$OUTDIR/file.json")"
FILE_NAME="$(jq -r '.file.name' "$OUTDIR/file.json")"
```

### 3) Wait for video processing

```bash
for i in $(seq 1 60); do
  curl -sS "https://generativelanguage.googleapis.com/v1beta/${FILE_NAME}?key=${GEMINI_API_KEY}" \
    > "$OUTDIR/file-status.json"
  STATE="$(jq -r '.file.state // empty' "$OUTDIR/file-status.json")"
  [ "$STATE" = "ACTIVE" ] && break
  [ "$STATE" = "FAILED" ] && { cat "$OUTDIR/file-status.json"; exit 1; }
  sleep 5
done
```

### 4) Generate the analysis

This follows the user's requested Gemini cURL shape while adding the uploaded video part:

```bash
cat > "$OUTDIR/prompt.md" <<'PROMPT'
Analyze the attached video.

Goal: INSERT_INPUT_HERE

Return an evidence-grounded summary, timestamped scene/action breakdown, visible text/UI details, audio/speech notes if present, direct answer, and uncertainties.
PROMPT

jq -n \
  --arg file_uri "$FILE_URI" \
  --arg mime_type "$MIME_TYPE" \
  --rawfile prompt "$OUTDIR/prompt.md" \
  '{
    contents: [
      {
        role: "user",
        parts: [
          { file_data: { mime_type: $mime_type, file_uri: $file_uri } },
          { text: $prompt }
        ]
      }
    ],
    generationConfig: {
      thinkingConfig: {
        thinkingLevel: "MINIMAL"
      }
    }
  }' > "$OUTDIR/request.json"

curl -sS -N \
  -X POST \
  -H "Content-Type: application/json" \
  "https://generativelanguage.googleapis.com/v1beta/models/${MODEL_ID}:${GENERATE_CONTENT_API}?key=${GEMINI_API_KEY}" \
  -d "@$OUTDIR/request.json" \
  > "$OUTDIR/response.json"

jq -r '.. | objects | .text? // empty' "$OUTDIR/response.json" > "$OUTDIR/analysis.md"
```

## Text-only / transcript fallback

If no video file is available but the user provides a transcript, screenshots, or notes, use the same model without `file_data`:

```bash
cat > request.json <<'JSON'
{
  "contents": [
    {
      "role": "user",
      "parts": [
        { "text": "INSERT_INPUT_HERE" }
      ]
    }
  ],
  "generationConfig": {
    "thinkingConfig": {
      "thinkingLevel": "MINIMAL"
    }
  },
  "tools": [
    { "googleSearch": {} }
  ]
}
JSON

curl -sS -N \
  -X POST \
  -H "Content-Type: application/json" \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite-preview:streamGenerateContent?key=${GEMINI_API_KEY}" \
  -d '@request.json'
```

## Response standards

When reporting findings to the user:

- Lead with the answer or summary.
- Include timestamps only as approximate unless the video clearly exposes exact timing.
- Separate **video evidence** from **Google Search context**.
- Call out uncertainty explicitly.
- If the API failed, report the status/error and the saved `response.json` path.
