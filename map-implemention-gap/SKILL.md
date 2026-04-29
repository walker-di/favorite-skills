---
name: map-implemention-gap
description: "Map gaps between an OpenSpec change/specification and the actual implementation by delegating static OpenSpec/code/test analysis plus real browser verification. Use when the user asks to compare OpenSpec intent against implemented behavior, audit completion, or find missing work before implementation/finalization, including map_implemention_gap / map-implemention-gap requests."
---

# map_implemention_gap

Use this skill when the user wants to map the gap between **OpenSpec artifacts** and the **actual implementation**.

This is an audit/planning workflow. Do **not** implement fixes unless the user explicitly asks afterward.

The skill must combine:

1. OpenSpec requirement extraction
2. Static implementation inspection across frontend/backend
3. Test coverage and validation inspection
4. Real browser verification of the running app
5. Parent-session unification and validation into one gap report

## Hard rules

- Do **not** implement, edit, write, or delete application code while mapping gaps.
- Use relevant OpenSpec workflow information before judging gaps.
- Use the browser skill / Playwright to run or inspect the actual app in a real browser flow.
- Browser verification is mandatory unless impossible; if impossible, document exactly why and what blocked it.
- Before execution, call `subagent({ action: "list" })` and choose executable agents.
- Do **not** use worktrees.
- Run all subagents in the current repo/folder.
- Subagents are investigation-only and must not edit files.
- Parent session must receive reports, deduplicate contradictions, validate severity, and produce one unified gap report.
- Create or update **one** gap artifact, not multiple report files.
- Prefer concrete file paths, OpenSpec requirement IDs/scenario names, URLs, screenshots, console errors, and command outputs over vague statements.

## Required subagents

Run these four analysis roles for every gap map:

1. `gap-spec-<topic>` — extracts OpenSpec requirements and intended behavior
2. `gap-code-<topic>` — inspects actual frontend/backend implementation against requirements
3. `gap-tests-<topic>` — inspects automated test and validation coverage gaps
4. `gap-browser-<topic>` — runs/inspects the app with Playwright and captures runtime/browser evidence

If the user scope is very small, still run all four roles, but instruct irrelevant agents to return `No material scope found` with reasoning.

## Delegation patterns

Single subtask example:

```text
subagent({ agent: "worker", task: "<focused audit prompt>" })
```

Primary execution (parallel, no worktree):

```text
subagent({
  tasks: [
    { agent: "worker", task: "<spec prompt>" },
    { agent: "backend-worker", task: "<code prompt>" },
    { agent: "qa-worker", task: "<tests prompt>" },
    { agent: "qa-worker", task: "<browser prompt>" }
  ],
  concurrency: 4,
  worktree: false
})
```

Optional dependent synthesis/review chain example:

```text
subagent({
  chain: [
    { agent: "planner", task: "Synthesize these four reports into a requirement matrix: {task}" },
    { agent: "reviewer", task: "Critique coverage, severity, and contradictions: {previous}" }
  ]
})
```

Status/control examples for async runs:

```text
subagent({ action: "status", id: "..." })
subagent({ action: "interrupt", id: "..." })
subagent({ action: "doctor" })
```

## OpenSpec change selection

If the user names a change, use that change.

If the change is missing or ambiguous:

1. Run:
   ```bash
   openspec list --json
   ```
2. If exactly one active change exists, use it and state the selection.
3. If multiple active changes exist, ask the user which change to audit.

Always announce:

```text
Using OpenSpec change: <change-name>
```

## Required OpenSpec commands

The parent or `gap-spec` subagent must run and inspect:

```bash
openspec status --change "<change-name>" --json
openspec instructions apply --change "<change-name>" --json
```

Read all context files returned by `instructions apply`, including proposal, design, specs, tasks, implementation docs, or schema-specific equivalents.

If OpenSpec CLI is missing, blocked, or no change exists, document it as a blocking issue and ask the user before continuing unless the user explicitly wants a best-effort audit.

## Shared child constraints

Every child prompt must include:

```text
You are mapping implementation gaps only. Do not implement, edit, write, or delete files.
Work in the existing repo folder only. Do not create a worktree.
Use concrete evidence: file paths, route paths, test names, OpenSpec scenario IDs, commands, URLs, screenshots, console/network observations.
Follow project instructions, clean architecture boundaries, Svelte 5/frontend architecture, API policies, and i18n/accessibility rules.
Return a concise but complete gap report.
Classify each gap as Critical, High, Medium, Low, or Question.
If something is ambiguous, record assumptions and unknowns instead of changing code.
```

## Spec child prompt template

```text
You are the OpenSpec requirements subagent for map_implemention_gap.

OpenSpec change:
<change-name>

Goal:
<user goal>

Scope:
- Run and inspect `openspec status --change "<change-name>" --json`.
- Run and inspect `openspec instructions apply --change "<change-name>" --json`.
- Read every context file returned by the OpenSpec CLI.
- Extract intended behavior, scenarios, acceptance criteria, non-goals, constraints, and task completion status.
- Do not judge code unless necessary to understand requirement references.
- Do not implement or edit files.

Report format:
1. OpenSpec framing and schema
2. Context files read
3. Requirement inventory with IDs/scenarios/tasks
4. Declared completion status from tasks
5. Acceptance criteria that need implementation verification
6. Ambiguities/unknowns in the spec
7. Requirement-to-evidence checklist for the parent
```

## Code child prompt template

```text
You are the static implementation subagent for map_implemention_gap.

OpenSpec change:
<change-name>

Goal:
<user goal>

Scope:
- Inspect actual frontend/backend/domain/infrastructure implementation relevant to the OpenSpec change.
- Compare code against likely requirements from OpenSpec artifacts and tasks.
- Check clean architecture boundaries, API wrapper usage, auth/cache policy, Svelte 5 idioms, i18n readiness, and existing patterns where applicable.
- Identify missing, partial, contradictory, or over-implemented behavior.
- Do not implement or edit files.

Report format:
1. Implementation areas inspected
2. Relevant files and routes
3. Implemented behavior found
4. Missing or partial behavior with evidence
5. Architecture/policy gaps
6. Risks and unknowns needing browser/test validation
7. Gap checklist with severity and file paths
```

## Tests child prompt template

```text
You are the test coverage subagent for map_implemention_gap.

OpenSpec change:
<change-name>

Goal:
<user goal>

Scope:
- Inspect existing tests relevant to the OpenSpec change.
- Compare tests against OpenSpec acceptance criteria and implementation behavior.
- Identify missing unit, repository, service, API route, UI model, component, e2e, and browser/manual coverage.
- Identify appropriate validation commands and the smallest meaningful command set.
- Run lightweight targeted test discovery commands if useful, but do not modify tests.
- Do not implement or edit files.

Report format:
1. Test areas inspected
2. Existing tests and commands found
3. Requirements covered by tests
4. Requirements not covered or weakly covered
5. Recommended tests to add/fix
6. Required validation commands
7. Test gap checklist with severity and file paths
```

## Browser child prompt template

```text
You are the browser verification subagent for map_implemention_gap.

OpenSpec change:
<change-name>

Goal:
<user goal>

Mandatory setup:
- Read `/Users/walker/.pi/agent/skills/use-browser/SKILL.md` before running browser verification.
- Use Playwright for browser investigation.
- Choose the lightest viable mode: headless by default, headed for visual/timing issues, user-browser when existing auth/session state is required.
- Run the actual app locally when needed. Use the project scripts from package.json/README/project instructions. If a dev server is already running, reuse it.
- Prefer `http://localhost:5173/` for local UI verification when applicable.
- Capture screenshots at meaningful checkpoints unless sensitive data prevents it.

Scope:
- Verify actual browser behavior against OpenSpec acceptance criteria.
- Capture visible UI state, interactions, console errors, network failures, route behavior, loading/empty/error states, and accessibility-affecting issues where possible.
- Do not implement or edit files.

Report format:
1. Browser mode and reason
2. App/server command or existing URL used
3. User flow/URLs exercised
4. Screenshots/evidence paths
5. Console/network/runtime observations
6. Behavior matching OpenSpec
7. Browser-observed gaps with severity
8. Blockers or auth/session limitations
```

## Parent workflow

1. Parse user goal and determine the OpenSpec change.
2. If ambiguous, ask for clarification or list active OpenSpec changes.
3. Announce `Using OpenSpec change: <change-name>`.
4. Read this skill and, before browser-related work, read the `use-browser` skill.
5. Call `subagent({ action: "list" })`.
6. Run the four role prompts in parallel via `subagent({ tasks: [...], concurrency: 4, worktree: false })`.
7. If async is used, monitor via `subagent({ action: "status", id: "..." })`.
8. If a subagent fails, retry once with a narrower prompt. If it fails again, record the failure as an audit limitation.
9. Unify reports by mapping each OpenSpec requirement/scenario/task to:
   - code evidence
   - test evidence
   - browser evidence
   - gap status
   - severity
   - recommended next action
10. Validate contradictions:
   - If code says implemented but browser says broken, mark as runtime gap.
   - If tasks are checked but no code/test/browser evidence exists, mark as evidence gap.
   - If browser cannot verify due to auth/setup, mark as blocked with exact blocker.
   - If implementation exceeds spec, mark as scope drift.
11. Save one report artifact, preferably:
   - `.pi/gaps/<change-name>-implementation-gap.md`
   - or an existing change-specific audit file if the repo already has one.
12. Return a concise summary and report path to the user.

## Gap status taxonomy

Use these statuses:

- ✅ **Satisfied** — spec requirement has code, test, and/or browser evidence as appropriate.
- ⚠️ **Partial** — some behavior exists but misses acceptance criteria or edge cases.
- ❌ **Missing** — no evidence of required behavior.
- 🐛 **Broken** — implemented but fails in browser/tests/runtime.
- 🌀 **Scope drift** — implementation adds behavior not requested or contradicts spec.
- ❓ **Unknown/Blocked** — insufficient evidence due to ambiguity, auth, missing server, missing fixtures, or environment issues.

Severity:

- **Critical** — blocks primary user flow, data integrity, auth/security, or release acceptance.
- **High** — major acceptance criteria missing/broken.
- **Medium** — important edge case, coverage, or UX gap.
- **Low** — polish, minor mismatch, documentation/test completeness.
- **Question** — spec ambiguity or needs product decision.

## Unified gap report artifact format

Use this structure:

```markdown
# <OpenSpec Change> Implementation Gap Report

## Summary
- OpenSpec change: `<change-name>`
- Audit goal: ...
- Overall status: ✅ Satisfied | ⚠️ Partial | ❌ Missing | 🐛 Broken | ❓ Blocked
- Highest severity: Critical | High | Medium | Low | Question

## Source Reports
-[x] ✅ OpenSpec requirements incorporated: `gap-spec-<topic>`
-[x] ✅ Static implementation incorporated: `gap-code-<topic>`
-[x] ✅ Test coverage incorporated: `gap-tests-<topic>`
-[x] ✅ Browser verification incorporated: `gap-browser-<topic>`

## Browser Verification
- Mode: headless | headed | user-browser
- URL(s): ...
- Screenshots: ...
- Console/network findings: ...
- Blockers: ...

## Requirement Gap Matrix

| Requirement / Scenario | Spec Source | Code Evidence | Test Evidence | Browser Evidence | Status | Severity | Next Action |
|---|---|---|---|---|---|---|---|
| ... | ... | ... | ... | ... | ⚠️ Partial | High | ... |

## Detailed Gaps

### ❌ Missing / 🐛 Broken / ⚠️ Partial: <short title>
- Severity: ...
- Spec evidence: ...
- Code evidence: ...
- Test evidence: ...
- Browser evidence: ...
- Impact: ...
- Recommended fix: ...

## Scope Drift
- 🌀 ...

## Test Coverage Gaps
-[ ] ...

## Recommended Implementation Checklist

### Backend
-[ ] ...

### UI/frontend
-[ ] ...

### Tests
-[ ] ...

### Validation
-[ ] Run ...
-[ ] Browser verify ...

## Open Questions / Blockers
- ❓ ...
```

## Final response format

```markdown
## Gap Map Ready

**OpenSpec change:** `<change-name>`
**Gap report:** `<path>`
**Overall status:** <status>
**Highest severity:** <severity>

### Top Gaps
- ...

### Browser Verification
- Mode: ...
- Evidence: ...
- Blockers: ...

### Delegated Reports
- ✅ OpenSpec: `gap-spec-<topic>`
- ✅ Code: `gap-code-<topic>`
- ✅ Tests: `gap-tests-<topic>`
- ✅ Browser: `gap-browser-<topic>`

### Next Step
Say "implement the gap fixes" when you want me to turn the checklist into code changes.
```

## Notes

- Keep the final response concise.
- Do not claim fixes were made.
- Browser verification is part of the audit, not optional polish.
- If the app cannot run, record exact command, error, and next unblock step.
- If authentication blocks browser verification, prefer `user-browser` mode or ask the user for guidance.
