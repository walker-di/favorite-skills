#!/usr/bin/env bash
set -e -Euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <video-path> [prompt] [outdir]" >&2
  exit 2
fi

: "${GEMINI_API_KEY:?Set GEMINI_API_KEY first}"
command -v curl >/dev/null || { echo "curl is required" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }
command -v file >/dev/null || { echo "file is required" >&2; exit 2; }

VIDEO_PATH="$1"
PROMPT_TEXT="${2:-Analyze this video. Provide an evidence-grounded summary, timestamped scene/action breakdown, visible text/UI details, audio/speech notes if present, direct answer, and uncertainties.}"
OUTDIR="${3:-artifacts/video-analysis/$(date +%F)-analysis}"
MODEL_ID="${GEMINI_MODEL_ID:-gemini-3.1-flash-lite-preview}"
GENERATE_CONTENT_API="${GEMINI_GENERATE_CONTENT_API:-streamGenerateContent}"

if [[ ! -f "$VIDEO_PATH" ]]; then
  echo "Video file not found: $VIDEO_PATH" >&2
  exit 2
fi

mkdir -p "$OUTDIR"

MIME_TYPE="$(file -b --mime-type "$VIDEO_PATH")"
NUM_BYTES="$(wc -c < "$VIDEO_PATH" | tr -d ' ')"
DISPLAY_NAME="$(basename "$VIDEO_PATH")"

cat > "$OUTDIR/prompt.md" <<PROMPT
$PROMPT_TEXT

Rules:
- Ground every claim in visible or audible evidence from the video.
- Do not invent exact timestamps, dialogue, UI text, or off-screen context.
- If using Google Search for background context, clearly separate searched context from video evidence.
PROMPT

printf '%s\n' "$VIDEO_PATH" > "$OUTDIR/source-video-path.txt"

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
if [[ -z "$UPLOAD_URL" ]]; then
  echo "Failed to get upload URL. See $OUTDIR/upload-headers.txt and $OUTDIR/upload-start.json" >&2
  exit 1
fi

curl -sS "$UPLOAD_URL" \
  -H "Content-Length: ${NUM_BYTES}" \
  -H "X-Goog-Upload-Offset: 0" \
  -H "X-Goog-Upload-Command: upload, finalize" \
  --data-binary "@${VIDEO_PATH}" \
  > "$OUTDIR/file.json"

FILE_URI="$(jq -r '.file.uri // empty' "$OUTDIR/file.json")"
FILE_NAME="$(jq -r '.file.name // empty' "$OUTDIR/file.json")"
if [[ -z "$FILE_URI" || -z "$FILE_NAME" ]]; then
  echo "Upload did not return file URI/name. See $OUTDIR/file.json" >&2
  exit 1
fi

STATE=""
for _ in $(seq 1 60); do
  curl -sS "https://generativelanguage.googleapis.com/v1beta/${FILE_NAME}?key=${GEMINI_API_KEY}" \
    > "$OUTDIR/file-status.json"
  STATE="$(jq -r '.file.state // empty' "$OUTDIR/file-status.json")"
  [[ "$STATE" == "ACTIVE" ]] && break
  if [[ "$STATE" == "FAILED" ]]; then
    echo "Gemini file processing failed. See $OUTDIR/file-status.json" >&2
    exit 1
  fi
  sleep 5
done

if [[ "$STATE" != "ACTIVE" ]]; then
  echo "Timed out waiting for Gemini file to become ACTIVE. Last state: ${STATE:-unknown}. See $OUTDIR/file-status.json" >&2
  exit 1
fi

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
    },
    tools: [
      { googleSearch: {} }
    ]
  }' > "$OUTDIR/request.json"

curl -sS -N \
  -X POST \
  -H "Content-Type: application/json" \
  "https://generativelanguage.googleapis.com/v1beta/models/${MODEL_ID}:${GENERATE_CONTENT_API}?key=${GEMINI_API_KEY}" \
  -d "@$OUTDIR/request.json" \
  > "$OUTDIR/response.json"

if jq -e . "$OUTDIR/response.json" >/dev/null 2>&1; then
  jq -r '.. | objects | .text? // empty' "$OUTDIR/response.json" > "$OUTDIR/analysis.md"
else
  cp "$OUTDIR/response.json" "$OUTDIR/analysis.md"
fi

echo "✅ Video analysis complete"
echo "Output: $OUTDIR"
echo "Analysis: $OUTDIR/analysis.md"
