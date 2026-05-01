---
name: spike
description: Prepare for a task by running a research spike in a delegated subagent. Use when the user wants investigation, discovery, architecture mapping, risk analysis, or implementation prep before coding. Always attribute the spike to a subagent, use no worktree, and prefer fast cursor models with quota-aware fallback.
---

# Spike

Use this skill when the user wants to **prepare for a task**, not implement it yet.

A spike is for:
- understanding the codebase
- mapping integration points
- identifying unknowns and risks
- comparing implementation options
- proposing a concrete execution plan

## Hard rules

- **Always** attribute the spike to a delegated subagent.
- **Never** do the spike entirely in the parent session.
- **Do not** use a worktree for a spike.
- Before execution, call `subagent({ action: "list" })` and choose an executable agent.
- Prefer model **cursor/gpt-5.3-codex** for spike runs.
- If the task is high-ambiguity or deep architecture, use **cursor/gpt-5.5**.
- If a run fails with quota/usage-limit (`usage limit`, `team plan`, `insufficient_quota`, `429`), retry with fallback ladder:
  1. `cursor/gpt-5.3-codex`
  2. `cursor/gpt-5.5`
  3. `openai/gpt-4o`
- A spike is investigation only. Do not implement unless the user explicitly changes scope.

## Execution pattern

Use a single delegated run with no worktree:

```text
subagent({
  agent: "worker",
  task: "<spike prompt>",
  model: "cursor/gpt-5.3-codex"
})
```

## Child prompt template

Use a prompt like this for the delegated agent:

```text
You are running a spike for preparation only.

Goal:
<user goal>

Constraints:
- Investigate only. Do not implement.
- Read code, search the repo, inspect docs, and trace relevant flows.
- No worktree. Work in the existing folder context only.
- Produce a concise spike report with:
  1. Problem framing
  2. Relevant codepaths/files
  3. Unknowns
  4. Risks
  5. Options considered
  6. Recommended approach
  7. Concrete next implementation steps
- If something is ambiguous, state assumptions clearly.
- End with a short "ready to implement" checklist.
```

## Parent workflow

1. Clarify the spike target if the request is vague.
2. Call `subagent({ action: "list" })`.
3. Run the spike with `subagent({ agent: "...", task: "..." })`.
4. If needed, inspect runtime health with `subagent({ action: "doctor" })`.
5. If running async, monitor with `subagent({ action: "status", id: "..." })` and stop with `subagent({ action: "interrupt", id: "..." })` if required.
6. When the child finishes, summarize the findings for the user.
7. Keep the result clearly attributed to the subagent.

## Output style

When reporting back, prefer this structure:

```markdown
## Spike Summary

**Subagent**: <agent-name>
**Model**: <cursor/gpt-5.3-codex | cursor/gpt-5.5 | openai/gpt-4o>

### Findings
- ...

### Risks / Unknowns
- ...

### Recommended approach
- ...

### Next steps
1. ...
2. ...
3. ...
```

## Notes

- If the user later wants implementation, switch out of spike mode and implement separately.
- If the user wants a saved artifact, optionally write the spike report to a local path such as `.pi/spikes/<topic>.md`.
- Do not present parent-session investigation as if it were the spike; the spike belongs to the delegated subagent.
