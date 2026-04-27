---
name: post-mortem
description: Run a post-session post-mortem to extract lessons, durable knowledge, and improvements from the just-finished work. Use after a session/task wraps up to reflect across multiple perspectives (process, code quality, knowledge, tooling, instructions) and to dispatch follow-ups via self-evolve, llm-wiki, and qmd ledgers.
---

# Post Mortem

Use this skill at the **end of a session** to look back on what just happened and capture improvements before context is lost.

A post-mortem is reflection + dispatch:
1. Reflect across several perspectives.
2. For each perspective, decide if there is a durable artifact to update.
3. Dispatch the update via the right specialist tool/skill (`self_evolve_artifact`, `wiki_*`, `append_ledger`, etc.).
4. Summarize what was changed and what was deferred.

## Hard rules

- Do **not** silently rewrite skills or instruction files. Use `self-evolve` so candidates are reviewed.
- Do **not** invent facts. Only record things that actually happened in the session.
- Keep the post-mortem itself short; push detail into the durable artifacts.
- Always end with a compact summary: what was captured, where, and what was left as an open question.

## Perspectives to walk through

Walk these in order. For each, ask "is there something durable to capture?" If no, skip.

1. **Goal vs outcome** – what was asked, what was delivered, what slipped.
2. **Process** – tool usage, wasted steps, missing context, retries, dead-ends.
3. **Code/artifact quality** – correctness, structure, tests, follow-ups.
4. **Knowledge gained** – facts, conventions, gotchas worth remembering.
5. **Instructions/skills** – were any skill, AGENTS.md, SYSTEM.md, or prompt unclear, missing, or wrong?
6. **Tooling/automation** – missing scripts, repeated manual steps, flaky commands.
7. **Open questions / risks** – what is still unknown or fragile.

## Dispatch matrix

Pick the right destination per perspective:

| Perspective | Destination | Tool |
|---|---|---|
| Durable factual knowledge (decisions, conventions, gotchas tied to a project/topic) | qmd ledger | `append_ledger` (mode `autopilot` for notes, `gated` if it needs review) |
| Conceptual / interlinked knowledge that benefits from a wiki page | llm-wiki | `wiki_search` first, then `wiki_ensure_page` / `wiki_capture_source`, then `wiki_log_event` |
| Instruction artifact that misled the agent (SKILL.md, AGENTS.md, SYSTEM.md, APPEND_SYSTEM.md, prompts) | local artifact | `self-evolve` skill (do **not** edit in place) |
| Repeated manual workflow worth scripting | repo / dotfiles | propose to user; do not auto-create |
| Open risks/follow-ups | qmd ledger (e.g. `pending` or a TODO ledger) | `append_ledger` with `gated` |

If unsure which ledger exists, call `ledger_stats` or `describe_ledger` first.
If the wiki is not bootstrapped, skip wiki dispatch and note it in the summary.

## Workflow

1. **Confirm scope.** Ask the user if anything specific should be emphasized; otherwise default to "the just-finished session." Do not re-read every file — rely on session memory and only spot-check artifacts that were touched.
2. **Reflect** through the perspectives list. Produce a short bullet list internally.
3. **Pre-check infra** (cheap):
   - `ledger_stats` to see available ledgers.
   - `wiki_status` to see if a wiki exists.
4. **Dispatch** updates per the matrix. Batch independent calls in parallel where possible.
   - For instruction fixes, invoke the **self-evolve** skill on the specific file. Do not call `self_evolve_artifact` directly here — defer to that skill so candidates are reviewed.
   - For wiki entries, prefer `wiki_ensure_page` over creating files by hand, and finish with `wiki_log_event` (`kind: integrate` or `query`).
   - For ledger entries, match the existing schema (`describe_ledger` if unsure).
5. **Summarize** to the user:
   - Lessons captured (one line each)
   - Where each landed (path / ledger / wiki page)
   - Self-evolve candidates pending review (paths under `.pi/hermes-self-evolution/`)
   - Open items not yet captured and why

## What this skill does NOT do

- It does not implement code changes discovered during reflection. Surface them as follow-ups instead.
- It does not run `self_evolve_artifact` directly; it defers to the `self-evolve` skill.
- It does not bootstrap a wiki or initialize ledgers. If missing, mention it and stop for that perspective.
- It does not spawn side agents. Post-mortem runs in the parent session.

## Output template

End the skill with something like:

```
Post-mortem summary
- Goal vs outcome: <one line>
- Captured:
  - ledger:<name> ← <short note>
  - wiki:<path> ← <short note>
  - self-evolve queued: <artifact path> (review .pi/hermes-self-evolution/)
- Deferred / open:
  - <item> — <reason>
```
