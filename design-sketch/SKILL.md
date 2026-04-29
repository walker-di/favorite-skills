---
name: design-sketch
description: Create standalone HTML design proposals in ./.design_sketch relative to the current pi working directory. Use when the user asks for a design sketch, UI concept, HTML mockup, design proposal, visual direction, or alternative screen/layout concepts.
---

# Desigh Scketch

Create polished **HTML design proposal files** that live in the user's project folder, under:

```text
./.design_sketch/
```

The path is always relative to the current working directory from pi's point of view — the folder where the user started `pi.dev` / the active project root. Do not put generated design sketches in the skill directory or a global temp folder.

## Core Rule

When this skill is used, create one or more standalone `.html` files in `./.design_sketch/`.

Examples:

```text
./.design_sketch/dashboard-redesign.html
./.design_sketch/onboarding-flow-v2.html
./.design_sketch/pricing-page-options.html
```

If the folder does not exist, create it first.

## What to Produce

A design sketch should be a **self-contained HTML proposal**:

- Inline CSS in a `<style>` block.
- Inline JavaScript only when it helps demonstrate interaction.
- No build step required.
- No external project source modifications unless the user explicitly asks.
- Prefer no external assets; use CSS, gradients, SVG, emoji, icons via inline text, or embedded placeholders.
- If external fonts or CDN assets are used, keep the design usable without them.

The result should be easy for the user to open directly in a browser.

## Workflow

1. Understand the target product, page, component, or flow.
2. Inspect relevant project files only if needed to match existing product terminology, routes, visual language, or data shape.
3. Create `./.design_sketch/` in the current working directory if missing.
4. Write a named `.html` proposal file there.
5. If multiple distinct directions are useful, either:
   - put them as sections inside one HTML file, or
   - create multiple clearly named HTML files.
6. Report the created file path(s) and briefly summarize the design direction.

## Design Proposal Quality Bar

Each HTML file should include:

- A clear title and short design rationale.
- Realistic product copy, not lorem ipsum.
- Enough screen context to evaluate the idea.
- Strong visual hierarchy.
- Responsive layout basics for desktop and mobile widths.
- Component states where relevant: default, hover, selected, empty, loading, error, success.
- Notes or callouts explaining important design decisions when helpful.

## File Naming

Use kebab-case names based on the request:

```text
./.design_sketch/<topic>-<variant>.html
```

Examples:

- `checkout-flow-premium.html`
- `agent-dashboard-concept.html`
- `mobile-navigation-options.html`

If replacing or iterating an existing design sketch, prefer a version suffix unless the user asked to overwrite:

```text
./.design_sketch/settings-redesign-v2.html
```

## HTML Structure Guidance

Use a structure like:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Design Proposal</title>
  <style>
    /* self-contained proposal styles */
  </style>
</head>
<body>
  <main>
    <!-- proposal -->
  </main>
</body>
</html>
```

## Interaction Guidance

Use lightweight inline JavaScript only for proposal clarity, such as:

- toggling tabs
- switching variants
- opening a mock modal
- changing selected states
- previewing a responsive menu

Do not introduce frameworks or package dependencies for a design sketch.

## Verification

After writing the file:

- Confirm it exists under `./.design_sketch/`.
- Optionally run a simple check such as listing the folder.
- If the user asks for browser verification or visual QA, use the browser workflow to open the local HTML file and inspect it.

## Response Format

Keep the final response concise:

- List created file path(s).
- Summarize the design idea in 1-3 bullets.
- Mention how to open it, e.g. `open ./.design_sketch/example.html`.
