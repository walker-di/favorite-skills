---
name: imagen
description: Generate or edit images with ChatGPT Image 2 via terminal cURL. Use when the user asks for visual assets such as blog eyecatches, YouTube thumbnails, YouTube storyboard frames, Instagram posts, ads banners, social images, hero images, concept art, or image edits using uploaded/reference images.
---

# Imagen — ChatGPT Image 2 via terminal cURL

Use this skill to create and edit production-ready marketing/editorial images with **ChatGPT Image 2** from the terminal, while keeping prompts, source images, and outputs organized for repeatable asset workflows.

Default to terminal cURL/API usage. If the user explicitly asks to use the ChatGPT web UI, follow the **ChatGPT web workflow** section.

## Prerequisites

- The shell must have `OPENAI_API_KEY` set.
- Prefer `jq` for response parsing.
- Default model name: `gpt-image-2`.
  - If the API rejects that model, do not guess silently. Tell the user the model may not be enabled for their account and ask whether to use their configured image model.
  - Allow override with `OPENAI_IMAGE_MODEL`, for example:

```bash
export OPENAI_IMAGE_MODEL="gpt-image-2"
```

## Output hygiene

For every image task, create a dedicated folder unless the user specifies one:

```bash
mkdir -p assets/imagen/YYYY-MM-DD-short-slug
```

Inside it, save:

- `prompt.md` — the final prompt and any negative constraints.
- `request.json` or `request.form.txt` — the exact API request payload/fields.
- `response.json` — the raw API response, if practical.
- `output.png` / `output-01.png` etc. — generated or edited image files.
- `source-*` copies or symlinks when editing/reference images are used.

Never overwrite a good output without asking. Use numbered filenames for variants.

## First ask / clarify

Before generating, collect only what is needed:

1. **Asset type**: blog eyecatch, YouTube thumbnail, storyboard frame, Instagram post, ads banner, hero image, etc.
2. **Canvas/aspect ratio**:
   - Blog eyecatch / OG: usually `1536x1024` or `1200x630` final crop.
   - YouTube thumbnail: final `1280x720` (generate landscape, then crop/resize if needed).
   - Storyboard frame: usually `16:9` landscape.
   - Instagram square post: `1:1`.
   - Instagram portrait/reel cover: `4:5` or `9:16` final crop.
   - Ads banner: ask exact platform and dimensions.
3. **Message/hook**: what must the image communicate in 1 second?
4. **Audience and emotion**: technical, premium, playful, urgent, cinematic, etc.
5. **Brand constraints**: colors, typography style, logo usage, forbidden motifs.
6. **Text in image**: exact words, if any. Keep text short; image models may distort small text.
7. **References/source images**: required for edits, style matching, products, people, or brand consistency.

If the user gives enough detail, proceed without over-questioning and state assumptions.

## Prompt structure

Write prompts as art direction, not vague requests. Include:

```text
Asset: <type and platform>
Canvas: <aspect ratio / target crop>
Subject: <main visual subject>
Message: <one-sentence communication goal>
Composition: <foreground/midground/background, focal point, empty space for text>
Style: <photographic/3D/editorial/vector/cinematic/etc.>
Lighting/color: <specific palette and mood>
Text: <exact text or "no text">
Brand constraints: <logo/color/type/avoidances>
Quality constraints: crisp, high contrast, no watermarks, no extra logos, no distorted hands/faces, no unreadable microtext
```

For marketing assets, prioritize **one focal idea** and strong negative space for copy. For YouTube thumbnails, prefer large readable shapes, high contrast, emotional clarity, and no tiny details.

## Common sizes / generation choices

Use the closest supported generation size and crop/resize afterward when necessary.

| Use case | Preferred generation shape | Final target |
|---|---:|---:|
| Blog eyecatch / hero | `1536x1024` | `1200x630`, `1600x900`, or site-specific |
| YouTube thumbnail | `1536x1024` landscape, then crop | `1280x720` |
| Storyboard frame | `1536x1024` landscape | `16:9` project size |
| Instagram square | `1024x1024` | `1080x1080` |
| Instagram portrait | `1024x1536` | `1080x1350` |
| Vertical cover / story | `1024x1536`, then extend/crop | `1080x1920` |
| Display ad banner | Generate larger/correct ratio if supported, otherwise compose/crop manually | exact ad spec |

Suggested API fields:

- `size`: `1024x1024`, `1536x1024`, `1024x1536`, or `auto` if unsure.
- `quality`: `high` for production, `medium` for drafts, `low` for cheap exploration.
- `background`: `opaque` by default; `transparent` only when explicitly useful.
- `output_format`: `png` for design work; `jpeg`/`webp` if user asks for web compression.

## Generate image with cURL

Use JSON for generation requests.

```bash
MODEL="${OPENAI_IMAGE_MODEL:-gpt-image-2}"
OUTDIR="assets/imagen/$(date +%F)-short-slug"
mkdir -p "$OUTDIR"

cat > "$OUTDIR/prompt.md" <<'PROMPT'
Asset: YouTube thumbnail
Canvas: 16:9 landscape, final crop 1280x720
Subject: A surprised creator holding a glowing analytics dashboard
Message: This video reveals a hidden growth lever
Composition: big face on right, glowing dashboard on left, clean dark negative space at top-left for title text
Style: cinematic editorial thumbnail, realistic but slightly stylized, bold readable shapes
Lighting/color: electric blue and warm orange rim light, high contrast
Text: no text
Quality constraints: crisp, no watermark, no fake UI text, no extra logos, no distorted hands or face
PROMPT

jq -n \
  --arg model "$MODEL" \
  --rawfile prompt "$OUTDIR/prompt.md" \
  '{model:$model, prompt:$prompt, size:"1536x1024", quality:"high", background:"opaque", output_format:"png"}' \
  > "$OUTDIR/request.json"

curl -sS https://api.openai.com/v1/images/generations \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d @"$OUTDIR/request.json" \
  -o "$OUTDIR/response.json"

jq -r '.data[0].b64_json' "$OUTDIR/response.json" | base64 --decode > "$OUTDIR/output-01.png"
```

After generation, inspect the output before claiming success. If the response has no `.data[0].b64_json`, read `response.json` and report the API error clearly.

## Generate multiple variants

If the user asks for options, generate 2–4 variants with deliberate differences. Do not only change adjectives.

```bash
for i in 1 2 3; do
  jq -n \
    --arg model "${OPENAI_IMAGE_MODEL:-gpt-image-2}" \
    --rawfile prompt "$OUTDIR/prompt.md" \
    --arg variant "Variant $i: change composition and camera angle while preserving message." \
    '{model:$model, prompt:($prompt + "\n" + $variant), size:"1536x1024", quality:"high", output_format:"png"}' \
    > "$OUTDIR/request-$i.json"

  curl -sS https://api.openai.com/v1/images/generations \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d @"$OUTDIR/request-$i.json" \
    -o "$OUTDIR/response-$i.json"

  jq -r '.data[0].b64_json' "$OUTDIR/response-$i.json" | base64 --decode > "$OUTDIR/output-$i.png"
done
```

## Edit an image with cURL

Use edits when the user provides an image and asks to change part/all of it, preserve identity/product/brand, create a variant, remove objects, extend a scene, change background, or adapt an existing asset.

Single-image edit:

```bash
MODEL="${OPENAI_IMAGE_MODEL:-gpt-image-2}"
OUTDIR="assets/imagen/$(date +%F)-edit-short-slug"
mkdir -p "$OUTDIR"
cp /path/to/source.png "$OUTDIR/source.png"

cat > "$OUTDIR/prompt.md" <<'PROMPT'
Edit this image into a YouTube thumbnail background.
Preserve the subject identity and main pose.
Replace the background with a cinematic dark blue studio gradient, add subtle orange rim light, increase contrast, and leave clean empty space on the left for large title text.
Do not add text, logos, watermarks, extra fingers, or change the person's face.
PROMPT

cat > "$OUTDIR/request.form.txt" <<EOF
model=$MODEL
image=@$OUTDIR/source.png
prompt=$(cat "$OUTDIR/prompt.md")
size=1536x1024
quality=high
output_format=png
EOF

curl -sS https://api.openai.com/v1/images/edits \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F "model=$MODEL" \
  -F "image=@$OUTDIR/source.png" \
  -F "prompt=<${OUTDIR}/prompt.md" \
  -F "size=1536x1024" \
  -F "quality=high" \
  -F "output_format=png" \
  -o "$OUTDIR/response.json"

jq -r '.data[0].b64_json' "$OUTDIR/response.json" | base64 --decode > "$OUTDIR/edited-01.png"
```

Multiple reference/source images, if supported for the account/API version, use repeated multipart image fields. Try the documented form first; if rejected, fall back to one primary image and describe the other references in the prompt.

```bash
curl -sS https://api.openai.com/v1/images/edits \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F "model=${OPENAI_IMAGE_MODEL:-gpt-image-2}" \
  -F "image[]=@source-product.png" \
  -F "image[]=@style-reference.png" \
  -F "prompt=<prompt.md" \
  -F "size=1536x1024" \
  -F "quality=high" \
  -F "output_format=png" \
  -o response.json
```

## Masked/local edits

If the user wants to change only a region, ask for or create a mask if practical. Mask conventions vary by API version, but usually transparent pixels indicate the editable area and opaque pixels protect the original. Confirm with current API errors/docs if mask upload is rejected.

```bash
curl -sS https://api.openai.com/v1/images/edits \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F "model=${OPENAI_IMAGE_MODEL:-gpt-image-2}" \
  -F "image=@source.png" \
  -F "mask=@mask.png" \
  -F "prompt=<prompt.md" \
  -F "size=1024x1024" \
  -F "quality=high" \
  -F "output_format=png" \
  -o response.json
```

## ChatGPT web workflow

Use this only when the user explicitly asks for the web UI or when API access is unavailable and the user accepts manual/browser generation.

1. Open ChatGPT in the browser.
2. Choose the model/tool labeled **ChatGPT Image 2** or image generation.
3. Start with a compact creative brief using the prompt structure above.
4. Upload source/reference images for edits, product consistency, style matching, or character continuity.
5. Ask for 2–4 distinct directions if exploring.
6. Iterate one change at a time: composition, lighting, crop, background, text area, etc.
7. Download the selected image and save it in the same output folder with the prompt/notes.
8. For final production, crop/resize/compress outside ChatGPT if exact platform dimensions are required.

When using the web UI from pi, load the `use-browser` skill if browser interaction/debugging is required.

## Asset-specific guidance

### Blog eyecatch / OG image

- Communicate the article thesis, not a generic stock-photo concept.
- Use a clear metaphor, strong center/left-right structure, and safe crop margins.
- Avoid detailed text unless user provides exact large headline text.

### YouTube thumbnail

- One emotional focal point + one concrete object/visual proof.
- High contrast, large shapes, simple silhouette.
- Leave negative space for title text unless text is generated separately in design software.
- Prefer no embedded text from the image model unless it is very short and must be part of the image.

### YouTube storyboard image

- Keep continuity: character identity, camera lens, lighting, location, wardrobe, and color grade.
- Name each frame: `frame-01.png`, `frame-02.png`, etc.
- Include shot type and camera motion in prompt: wide, medium, close-up, over-the-shoulder, top-down, etc.

### Instagram post

- Design for mobile first: bold subject, not too much small detail.
- Square or portrait; keep important content away from edges.
- For carousels, keep visual system consistent across slides.

### Ads banner

- Ask for exact platform/placement/dimensions and CTA.
- Generate background/hero art, then add exact text and logos in a deterministic design tool when possible.
- Respect brand colors and ad policy constraints.

## Review checklist

Before reporting completion, verify:

- The output file exists and is non-empty.
- Aspect ratio is appropriate or a post-processing note is provided.
- No watermarks, fake logos, unwanted text, distorted faces/hands, or brand violations.
- The visual matches the user's message and platform.
- The prompt and request are saved for reproducibility.

## Failure handling

- If `OPENAI_API_KEY` is missing, ask the user to set it; do not print or request secret values in chat.
- If the model is unavailable, show the API error and ask whether to use a different enabled image model.
- If base64 decoding fails, inspect `response.json` for an error object.
- If exact typography/logos are required, recommend generating background art first and compositing final text/logos separately.
