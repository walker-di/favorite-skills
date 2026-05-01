---
name: plan-implemention
description: "Plan a feature implementation by delegating investigation to three no-edit-safe, no-worktree subagents: one for UI/frontend, one for backend, and one for tests. Use when the user asks to plan implementation before coding or explicitly invokes plan_implemention / plan-implemention."
---

# plan_implemention

Use this skill when the user explicitly requests an implementation plan before coding, especially when they say `plan_implemention`, "plan implementation", "create a plan", or "plan before implementing".

**Do not use** for direct implementation requests, debugging, or when the user asks to "implement" or "build" without planning.

The skill produces one unified, validated implementation plan by delegating planning to exactly three subagents:

1. **UI/frontend planning subagent**
2. **Backend planning subagent** 
3. **Tests planning subagent**

This is a planning workflow only. Do **not** implement code unless the user later asks for implementation.

## Hard rules

- Delegate **three** planning subtasks for every plan:
  - `plan-ui-<topic>`
  - `plan-backend-<topic>`
  - `plan-tests-<topic>`
- Before execution, call `subagent({ action: "list" })` and choose executable no-edit-safe agents.
- Use no-edit-safe planning agents by default: `delegate` for role-specific planning or `planner` where appropriate.
- Avoid implementation-specialist agents (`frontend-worker`, `backend-worker`, `qa-worker`) unless their harness explicitly supports no-edit planning mode.
- Prefer `cursor/gpt-5.3-codex` for planning subtasks to reduce latency.
- If planning quality is insufficient, escalate to `cursor/gpt-5.5`.
- If a subagent fails with quota/usage-limit (`usage limit`, `team plan`, `insufficient_quota`, `429`), retry with fallback ladder:
  1. `cursor/gpt-5.3-codex`
  2. `cursor/gpt-5.5` 
  3. `openai/gpt-4o`
- Do **not** use worktrees for this workflow.
- Run all subagents in current repo/folder context.
- Subagents must investigate and plan only; they must not edit files.
- Parent session must receive all three reports, then unify and validate them.
- Create or update **one** plan artifact in the repo, not multiple plan files.
- Include a checklist with tasks grouped by UI/frontend, backend, tests, validation, risks, and dependencies.

## Output handling and recovery

**Critical**: When a subagent returns a report but harness flags "completed without making edits" or similar:

1. **Read the output artifact** using the reported path or standard output location
2. **Validate content** against the planning prompt requirements:
   - Does it address the assigned planning scope?
   - Does it include the required report sections?
   - Is the content substantive and actionable?
3. **If content is adequate**: Treat as successful planning report and incorporate into unified plan
4. **If content is inadequate**: Retry with adjusted prompt or different no-edit-safe agent
5. **Switch future subtasks** to confirmed no-edit-safe agents to prevent recurrence

**Output modes**:
- Use `output: false` for subagents that should return content directly without file creation
- Use file output when creating persistent planning artifacts
- Monitor both direct output and file artifacts for comprehensive content validation

## Delegation patterns

Single subtask example:
```text
subagent({ agent: "delegate", task: "<focused planning prompt>", model: "cursor/gpt-5.3-codex", output: false })
```

Primary execution (parallel, no worktree):
```text
subagent({
  tasks: [
    { agent: "delegate", task: "<ui planning prompt>", model: "cursor/gpt-5.3-codex", output: false },
    { agent: "delegate", task: "<backend planning prompt>", model: "cursor/gpt-5.3-codex", output: false },
    { agent: "delegate", task: "<tests planning prompt>", model: "cursor/gpt-5.3-codex", output: false }
  ],
  concurrency: 3,
  worktree: false
})
```

If `delegate` is unavailable, choose another confirmed no-edit-safe planning agent from `subagent({ action: "list" })`.

Status/control examples:
```text
subagent({ action: "status", id: "..." })
subagent({ action: "interrupt", id: "..." })
subagent({ action: "doctor" })
```

## Shared child constraints

Every child prompt must include:
```text
You are planning only. Do not implement, edit, write, or delete files.
Work in the existing repo folder only. Do not create a worktree.
Read relevant docs, README files, existing examples, and related code.
Follow project instructions, clean architecture boundaries, existing patterns, and i18n rules.
Return a concise but complete planning report.
If you find uncertainty, record assumptions and risks instead of changing code.
```

## UI/frontend child prompt template

```text
You are the UI/frontend planning subagent for plan_implemention.

Goal: <user goal>

Scope:
- Plan Svelte/SvelteKit UI work only.
- Identify pages, components, domain folders, hooks, models, shadcn/ui primitives, labels/i18n needs, and API wrapper usage.
- Follow Svelte 5 idioms, atomic design, model-view separation, and frontend clean architecture.
- Check relevant domain README.md files and related examples.
- Do not implement or edit files.

Report format:
1. UI problem framing
2. Relevant frontend files and patterns
3. Proposed component/domain structure
4. State/model/data-flow plan
5. i18n/accessibility plan
6. Risks, assumptions, and dependencies on backend
7. UI checklist items with file paths
```

## Backend child prompt template

```text
You are the backend planning subagent for plan_implemention.

Goal: <user goal>

Scope:
- Plan backend/API/domain/infrastructure work only.
- Identify routes, services, repositories, schemas, migrations, auth policy, environment variables, WebSocket/event needs, and clean architecture boundaries.
- Follow domain rules: repositories handle persistence details, APIs use plain strings, services hold use cases, detailed error logging in catch blocks.
- For migrations: include rollback strategies and dependency validation.
- Check relevant README.md/docs and related examples.
- Do not implement or edit files.

Report format:
1. Backend problem framing
2. Relevant backend/domain files and patterns
3. API/service/repository plan
4. Data model/migration/index plan with rollback strategy, if applicable
5. Auth, validation, error logging, and eventing plan
6. Risks, assumptions, and dependencies on UI/tests
7. Backend checklist items with file paths
```

## Tests child prompt template

```text
You are the tests planning subagent for plan_implemention.

Goal: <user goal>

Scope:
- Plan the smallest meaningful validation strategy for the change scope.
- Identify unit, integration, repository, route, UI model, component, e2e, and manual/browser checks as applicable.
- Follow project test conventions: frontend Vitest, backend Jest, repository assertNoRecordIdLeaks where relevant, and required root npm validation for code-impacting changes.
- Check existing test files and examples.
- Do not implement or edit files.

Report format:
1. Test problem framing
2. Existing test patterns/files to reuse
3. Proposed automated tests by layer
4. Manual/browser verification plan, if applicable
5. Required commands and smallest meaningful validation
6. Risks, assumptions, and fixtures/mocks needed
7. Tests checklist items with file paths
```

## Parent workflow

1. Parse the user goal and clarify if required.
2. Create a short kebab-case `<topic>` for report labels.
3. Call `subagent({ action: "list" })` and select confirmed no-edit-safe planning agents.
4. Run three role-specific planning subtasks in parallel with `subagent({ tasks: [...], concurrency: 3, worktree: false })`.
5. For each subagent result:
   - If harness flags "completed without making edits", read output artifact and validate content
   - If content meets planning requirements, treat as successful report
   - If content is inadequate, retry with different agent or adjusted prompt
6. Validate each report against user requirements, project instructions, and architecture boundaries.
7. Resolve contradictions between reports in the parent session.
8. Produce one unified implementation plan.
9. Save as single plan file: `.pi/plans/<topic>-implementation-plan.md` or existing task-specific plan file.
10. Report the plan path and concise summary to the user.

## Unified plan artifact format

```markdown
# <Feature/Task> Implementation Plan

## Summary
- Goal: ...
- Assumptions: ...
- Non-goals: ...

## Source Reports
- [x] ✅ UI/frontend planning report incorporated: `plan-ui-<topic>`
- [x] ✅ Backend planning report incorporated: `plan-backend-<topic>`
- [x] ✅ Tests planning report incorporated: `plan-tests-<topic>`

## Architecture Validation
- ✅ Clean architecture boundaries: ...
- ✅ Svelte 5/frontend idioms: ...
- ✅ API/infrastructure boundaries: ...
- ✅ i18n/accessibility: ...
- ✅ Testing strategy: ...

## Implementation Checklist

### UI/frontend
- [ ] ...

### Backend  
- [ ] ...

### Tests
- [ ] ...

### Validation
- [ ] Run ...
- [ ] Browser verify ...

## Dependencies and Sequencing
1. ...
2. ...

## Risks and Mitigations
- ⚠️ Risk: ...
  - Mitigation: ...

## Open Questions
- ❓ ...
```

## Final response format

```markdown
## Plan Ready

**Plan file:** `<path>`

### Unified Summary
- ...

### Delegated Reports
- ✅ UI/frontend: `plan-ui-<topic>`
- ✅ Backend: `plan-backend-<topic>`
- ✅ Tests: `plan-tests-<topic>`

### Next Step
Say "implement this plan" when you want me to start executing the checklist.
```

## Notes

- Keep final response concise.
- Do not claim implementation occurred.
- For quota-limited failures, retry with model fallback ladder before changing prompt scope.
- For non-quota failures, retry once with narrower prompt. If it fails again, complete missing section in parent with failure disclosed.
- Always validate artifact content when harness indicates "no edits" to distinguish successful planning from failed implementation.
- Prefer concrete file paths over vague tasks in checklists.
