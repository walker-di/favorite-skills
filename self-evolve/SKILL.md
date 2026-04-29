---
name: self-evolve
description: Run Hermes /evolve on a local instruction artifact such as SKILL.md, AGENTS.md, SYSTEM.md, APPEND_SYSTEM.md, or a pi prompt file, usually via delegated subagent but directly for lifecycle/orchestration fixes. Use when the user wants to improve, tune, or evolve an instruction artifact without editing it in place.
---

# Self Evolve

Use this skill when the user wants to improve an instruction artifact and review generated candidates before applying changes.

## What this skill does

- Resolves the target artifact path
- Runs the evolve workflow, directly or in one controlled delegated subagent
- Uses `self_evolve_artifact` for actual generation
- Reports generated report/candidate paths
- Does not apply changes unless explicitly authorized

## Preferred targets

Use this skill for:

- `SKILL.md`
- `AGENTS.md`
- `SYSTEM.md`
- `APPEND_SYSTEM.md`
- prompt markdown under `~/.pi/agent/prompts/` or `.pi/prompts/`

Do **not** use this skill for normal source-code refactors.

## Path resolution

Prefer an explicit user path.

If the user gives only a skill name, resolve in this order:

1. `~/.pi/agent/skills/<name>/SKILL.md`
2. `.pi/skills/<name>/SKILL.md` in the current project
3. Ask for clarification if still ambiguous

If the user says "my AGENTS" or "system prompt", resolve these first:

- `~/.pi/agent/AGENTS.md`
- `~/.pi/agent/SYSTEM.md`
- project `.pi/AGENTS.md` / `AGENTS.md` / `.pi/SYSTEM.md` only if the user clearly means the current project

## Recursion guard

Before delegating, check whether you are already in a nested delegated context:

- current path or an ancestor matches `pi-worktree-*` (current pi-subagents worktree semantics, including temp/current path aliases that resolve under such ancestors)
- the request is about stuck delegated runs, stale worktrees, child lifecycle, orchestration, orphan worktrees, or this skill itself
- **Legacy side-agent cleanup guards:** current path or an ancestor matches `.pi-agent-worktree-*`, or an `active.lock` exists in legacy side-context state

If any guard is true, do **not** spawn another delegation layer and do **not** call `/evolve`. Run `self_evolve_artifact` directly in the current session. This prevents nested chains and orphaned worktrees across current pi-subagents and legacy side-agent contexts.

## Model selection

The `cursor` provider is **not supported** by litellm - always pass an explicit `model` parameter.

Preferred models for `self_evolve_artifact` (in order):

1. `anthropic/claude-sonnet-4-20250514` - fast, reliable, good for most artifacts
2. `openai/gpt-4o` - alternative if Anthropic quota is exhausted
3. `google/gemini-2.5-pro` - alternative for very large artifacts

Never omit the `model` parameter - the default will resolve to the cursor provider and fail.

## Subagent semantics reference

Before executing any delegated run, call:

```text
subagent({ action: "list" })
```

Standard patterns:

```text
subagent({ agent: "worker", task: "Run self_evolve_artifact for <TARGET_PATH> with explicit model" })
```

```text
subagent({ tasks: [{ agent: "worker", task: "..." }], concurrency: 1, worktree: false })
```

```text
subagent({ chain: [{ agent: "worker", task: "..." }] })
```

```text
subagent({ action: "status", id: "..." })
subagent({ action: "interrupt", id: "..." })
subagent({ action: "doctor" })
```

## Execution checklist

1. Confirm the exact target path.
2. Apply the recursion guard above.
3. If guarded, run `self_evolve_artifact` directly with an explicit model.
4. If not guarded, you may delegate one worker run through `subagent`.
5. Preserve the original file unless the user explicitly asks to apply a candidate.
6. Finish by reporting generated files and whether the original changed.

## Delegated task template

Use this only when the recursion guard is false.

```text
Run the evolve workflow for this artifact: <TARGET_PATH>

Requirements:
- Call self_evolve_artifact directly for <TARGET_PATH> with an explicit model.
- Do not call /evolve.
- Do not spawn additional delegated layers.
- Do not modify the original file in place.
- Return the report path, best candidate path, and a short summary of what improved.
- If the target path is invalid or ambiguous, stop and ask for clarification.
```

## Parent behavior for delegated runs

- Use one delegated run only when needed.
- For async runs, use `subagent({ action: "status", id: "..." })` as bounded monitoring.
- If the delegated run yields no useful progress, inspect with `subagent({ action: "doctor" })` and either refine prompt scope or interrupt.
- If termination is required, use `subagent({ action: "interrupt", id: "..." })`.
- Never wait indefinitely without status inspection.

## Output expectations

Always tell the user:

- target path
- report path
- candidate/best output path if provided
- whether anything was generated only
- whether the original artifact was modified
- if delegation was used, whether it completed, requested input, was interrupted, or appeared stuck

Generated files are typically under `.pi/hermes-self-evolution/` or the path reported by the child/tool. Recommend review before apply.

## Examples

- "Evolve `~/.pi/agent/skills/self-evolve/SKILL.md`."
- "Improve my global `AGENTS.md`."
- "Tune the prompt at `~/.pi/agent/prompts/review.md`."
- "Run self-evolve on the `backend-implementation` skill."
- “If already in `pi-worktree-0003` (or legacy `.pi-agent-worktree-0003` during cleanup), run `self_evolve_artifact` directly instead of `/evolve`."
