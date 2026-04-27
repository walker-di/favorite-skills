---
name: self-evolve
description: Run Hermes /evolve on a local instruction artifact such as SKILL.md, AGENTS.md, SYSTEM.md, APPEND_SYSTEM.md, or a pi prompt file, usually via side agent but directly for side-agent lifecycle fixes. Use when the user wants to improve, tune, or evolve an instruction artifact without editing it in place.
---

# Self Evolve

Use this skill when the user wants to improve an instruction artifact and review generated candidates before applying changes.

## What this skill does

- Resolves the target artifact path
- Runs the evolve workflow, directly or in one controlled side agent
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

Before considering `agent-start`, check whether you are already in a side-agent context:

- current path or an ancestor looks like `.pi-agent-worktree-*`
- an `active.lock` exists in the current side-agent/worktree state
- the request is about stuck side agents, stale worktrees, child lifecycle, agent orchestration, active locks, orphan worktrees, or this skill itself

If any guard is true, do **not** start another side agent and do **not** call `/evolve`. Run `self_evolve_artifact` directly in the current session. This prevents nested agent chains and orphaned worktrees.

## Execution checklist

1. Confirm the exact target path.
2. Apply the recursion guard above.
3. If guarded, run `self_evolve_artifact` directly.
4. If not guarded, you may use `agent-start` for the normal background workflow.
5. Preserve the original file unless the user explicitly asks to apply a candidate.
6. Finish by reporting generated files and whether the original changed.

## Side-agent task template

Use this only when the recursion guard is false.

```text
Run the evolve workflow for this artifact: <TARGET_PATH>

Requirements:
- Call self_evolve_artifact directly for <TARGET_PATH>.
- Do not call /evolve.
- Do not call agent-start or spawn any further side agents.
- Do not modify the original file in place.
- Return the report path, best candidate path, and a short summary of what improved.
- If the target path is invalid or ambiguous, stop and ask for clarification.
- If the run is complete and you need termination, request /quit.
```

## Parent behavior for child agents

Prefer `agent-start` only for unguarded normal requests, and manage the child actively:

- Use `agent-wait-any` only as a bounded wait for new output.
- Use `agent-check` and backlog/status inspection to distinguish done, waiting for input, still running, stuck, or needing `/quit`.
- If the child says it is done, provides final paths, or asks for `/quit`, send `/quit` promptly.
- After sending `/quit`, do not call `agent-wait-any` for that child again until status confirms termination or a waiting/stuck state.
- If the child yields twice without useful new output, stop waiting blindly; inspect status and either finalize, relay a question, send `/quit`, or report that the child appears stuck.
- Never leave the parent blocked indefinitely in `agent-wait-any`.

## Output expectations

Always tell the user:

- target path
- report path
- candidate/best output path if provided
- whether anything was generated only
- whether the original artifact was modified
- if a child was used, whether it completed, requested input, was quit, or appeared stuck

Generated files are typically under `.pi/hermes-self-evolution/` or the path reported by the child/tool. Recommend review before apply.

## Examples

- “Evolve `~/.pi/agent/skills/self-evolve/SKILL.md`.”
- “Improve my global `AGENTS.md`.”
- “Tune the prompt at `~/.pi/agent/prompts/review.md`.”
- “Run self-evolve on the `backend-implementation` skill.”
- “If already in `.pi-agent-worktree-0003`, run `self_evolve_artifact` directly instead of `/evolve`.”
