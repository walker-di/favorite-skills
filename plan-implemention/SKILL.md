---
name: plan-implemention
description: "Plan a feature implementation by delegating investigation to three no-worktree subagents: one for UI/frontend, one for backend, and one for tests. Use when the user asks to plan implementation before coding or explicitly invokes plan_implemention / plan-implemention."
---

# plan_implemention

Use this skill when the user wants an implementation plan before coding, especially when they explicitly say `plan_implemention`.

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
- Before execution, call `subagent({ action: "list" })` and choose executable agents.
- Do **not** use worktrees for this workflow.
- Run all subagents in the current repo/folder context.
- Subagents must investigate and plan only; they must not edit files.
- Parent session must receive all three reports, then unify and validate them.
- Create or update **one** plan artifact in the repo, not multiple plan files.
- Include a checklist with tasks grouped by UI/frontend, backend, tests, validation, risks, and dependencies.
- Mark planning tasks as complete only after their corresponding subagent report has been received and incorporated.
- If requirements are ambiguous, ask concise clarifying questions before spawning subagents. If the user asks to proceed anyway, document assumptions.

## Delegation patterns

Single subtask example:

```text
subagent({ agent: "frontend-worker", task: "<focused planning prompt>" })
```

Primary execution (parallel, no worktree):

```text
subagent({
  tasks: [
    { agent: "frontend-worker", task: "<ui planning prompt>" },
    { agent: "backend-worker", task: "<backend planning prompt>" },
    { agent: "qa-worker", task: "<tests planning prompt>" }
  ],
  concurrency: 3,
  worktree: false
})
```

Optional dependent synthesis/review chain example:

```text
subagent({
  chain: [
    { agent: "planner", task: "Synthesize these planning outputs into one checklist: {task}" },
    { agent: "reviewer", task: "Review this plan for contradictions and missing validation: {previous}" }
  ]
})
```

Status/control examples for async runs:

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

Goal:
<user goal>

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

Goal:
<user goal>

Scope:
- Plan backend/API/domain/infrastructure work only.
- Identify routes, services, repositories, schemas, migrations, auth policy, environment variables, WebSocket/event needs, and clean architecture boundaries.
- Follow domain rules: repositories handle persistence details, APIs use plain strings, services hold use cases, detailed error logging in catch blocks.
- Check relevant README.md/docs and related examples.
- Do not implement or edit files.

Report format:
1. Backend problem framing
2. Relevant backend/domain files and patterns
3. API/service/repository plan
4. Data model/migration/index plan, if applicable
5. Auth, validation, error logging, and eventing plan
6. Risks, assumptions, and dependencies on UI/tests
7. Backend checklist items with file paths
```

## Tests child prompt template

```text
You are the tests planning subagent for plan_implemention.

Goal:
<user goal>

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
3. Call `subagent({ action: "list" })`.
4. Run the three role-specific planning subtasks in parallel via `subagent({ tasks: [...], concurrency: 3, worktree: false })`.
5. If async is used, monitor with `subagent({ action: "status", id: "..." })`.
6. Validate each report against:
   - user requirements
   - project instructions
   - clean architecture boundaries
   - Svelte 5/frontend architecture rules
   - API/auth/cache policies, where relevant
   - test command requirements
7. Resolve contradictions between reports in the parent session.
8. Produce one unified implementation plan.
9. Save it as a single plan file when appropriate, preferably:
   - `.pi/plans/<topic>-implementation-plan.md`
   - or an existing task-specific plan file if the repo already has one for the work
10. Report the plan path and a concise summary to the user.

## Unified plan artifact format

Use this structure:

```markdown
# <Feature/Task> Implementation Plan

## Summary
- Goal: ...
- Assumptions: ...
- Non-goals: ...

## Source Reports
-[x] ✅ UI/frontend planning report incorporated: `plan-ui-<topic>`
-[x] ✅ Backend planning report incorporated: `plan-backend-<topic>`
-[x] ✅ Tests planning report incorporated: `plan-tests-<topic>`

## Architecture Validation
- ✅ Clean architecture boundaries: ...
- ✅ Svelte 5/frontend idioms: ...
- ✅ API/infrastructure boundaries: ...
- ✅ i18n/accessibility: ...
- ✅ Testing strategy: ...

## Implementation Checklist

### UI/frontend
-[ ] ...

### Backend
-[ ] ...

### Tests
-[ ] ...

### Validation
-[ ] Run ...
-[ ] Browser verify ...

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

- Keep the final response concise.
- Do not claim implementation occurred.
- If a subagent fails, retry once with a narrower prompt. If it fails again, report the failure and either ask the user how to proceed or complete only the missing section in the parent with the failure clearly disclosed.
- Prefer concrete file paths over vague tasks.
