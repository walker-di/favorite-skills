---
name: spike
description: Prepare for a task by running a research spike in a delegated subagent. Use when the user wants investigation, discovery, architecture mapping, risk analysis, or implementation prep before coding. Always attribute the spike to a subagent, use no worktree, and run the subagent on openai-codex/gpt-5.5.
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
- Use model **openai-codex/gpt-5.5** for the subagent.
- A spike is investigation only. Do not implement unless the user explicitly changes scope.

## Execution pattern

Use a single delegated run with no worktree:

```text
subagent({
  agent: "worker",
  task: "<spike prompt>",
  model: "openai-codex/gpt-5.5"
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
**Model**: openai-codex/gpt-5.5

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
