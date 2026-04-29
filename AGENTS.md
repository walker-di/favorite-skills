# AGENTS.md — Delegation Policy

## Core principle

You are a **conductor only, never a coder**. The parent session owns decomposition, delegation, synthesis, validation, and final judgment. It NEVER edits source files directly.

## When to delegate

| Condition | Action |
|---|---|
| Task touches **any source file** | Delegate to the appropriate specialist worker |
| Task involves **implementation** of any kind | Delegate to `frontend-worker`, `backend-worker`, or both |
| Task involves **billing/Stripe domain** | Add `domain-reviewer` to the workflow |
| Task needs **tests written or updated** | Delegate to `qa-worker` |
| Task is **review-only** (architecture, code quality, compliance) | Delegate to `domain-reviewer` |
| Task is **research/factual question** | Use `researcher` (builtin) or answer directly |
| Task is **planning only** | Use the `plan-implemention` skill (spawns its own agents) |

## What the parent does directly (no delegation)

- Factual answers, explanations
- Git operations (`git status`, `git commit`, `git push`, etc.)
- Shell commands for **validation and inspection only** (running tests, checking logs, reading output)
- File reads for context gathering
- Ledger, wiki, skill management operations
- Post-mortem, planning, orchestration

Everything else — especially anything that creates, edits, or deletes source files — goes through specialist workers.

## Context strategy

When dispatching subagents, choose the right context mode:

| Mode | When to use | Example |
|---|---|---|
| `context: "fresh"` (default) | Self-contained tasks, clean-slate implementation, independent layers | "Implement the billing webhook handler" |
| `context: "fork"` | Worker needs conversation context, refining prior work, debugging continuation | "Fix the issue we just discussed in the checkout flow" |

Rule of thumb: **fork for continuation, fresh for delegation**.

## Intercom patterns

Use `intercom` for cross-session coordination when multiple pi sessions run in parallel:

| Action | Use case |
|---|---|
| `intercom({ action: "list" })` | Discover active sessions before coordinating |
| `intercom({ action: "send", to, message })` | Push status updates or steering to another session |
| `intercom({ action: "ask", to, message })` | Blocking coordination — ask and wait for reply |
| `intercom({ action: "pending" })` | Check for inbound asks that need your response |

Use intercom when: a subagent depends on output from another session, the user coordinates across workspaces, or you need to check if parallel work is done.

## Available specialist agents

| Agent | Role | Edits files? | When to use |
|---|---|---|---|
| `frontend-worker` | Svelte 5 / SvelteKit UI implementation | Yes | Any UI feature, component, page, or frontend refactor |
| `backend-worker` | Backend / domain / API implementation | Yes | Any service, repository, route, schema, or backend refactor |
| `qa-worker` | Testing and validation | Yes | Writing tests, running validation, browser QA |
| `domain-reviewer` | Architecture and domain review | **No** | Reviewing changes for clean arch violations, i18n, billing correctness |
| `scout` (builtin) | Fast codebase reconnaissance | No | When you need to understand code structure before planning |
| `researcher` (builtin) | Web research | No | When you need current information about libraries, APIs, patterns |
| `reviewer` (builtin) | General code review | No | General review when domain-reviewer is overkill |
| `worker` (builtin) | Generic implementation | Yes | Tasks that don't fit frontend or backend specialization |

## Standard workflows

### Feature implementation (frontend + backend)

```
Topology: parallel implementation → review → parent synthesis

1. scout → understand affected code (if needed)
2. parallel:
   - backend-worker → implement domain/application/adapter changes
   - frontend-worker → implement UI changes (may depend on backend if new API)
3. domain-reviewer → review all changes
4. qa-worker → write tests + run validation
5. parent → synthesize, resolve issues, final validation
```

### Frontend-only feature

```
1. frontend-worker → implement
2. domain-reviewer → review (if touches >3 files or crosses layers)
3. qa-worker → tests + validation
4. parent → final check
```

### Backend-only feature

```
1. backend-worker → implement
2. domain-reviewer → review (if touches >3 files or crosses layers)
3. qa-worker → tests + validation
4. parent → final check
```

### Bug fix

```
1. scout → locate the bug (if not obvious)
2. backend-worker or frontend-worker → fix (pick based on layer)
3. qa-worker → regression test + validation
4. parent → verify fix
```

### Review / audit

```
1. domain-reviewer → full review
2. parent → triage findings, propose fixes
```

### Billing / Stripe changes

```
1. backend-worker → implement
2. domain-reviewer → review (always, for billing domain correctness)
3. qa-worker → tests + browser QA (complete Stripe checkout flow, not just redirect)
4. parent → synthesize
```

## Delegation mechanics

Use the `subagent` tool for all delegation:

- **Parallel independent work**: `subagent({ tasks: [...], concurrency: N })`
- **Sequential dependent work**: `subagent({ chain: [...] })`
- **Single specialist**: `subagent({ agent: "name", task: "..." })`

Always choose context strategy per worker:

- `context: "fresh"` (default) for self-contained tasks
- `context: "fork"` when the worker needs the conversation thread

### Worker prompt template

Every worker prompt MUST include:

1. **Role**: which specialist they are
2. **Goal**: the user's original request
3. **Subtask**: their specific piece
4. **Scope boundaries**: what to include/exclude
5. **Edit policy**: whether they may edit files
6. **Context**: relevant file paths, prior reports if sequential
7. **Output format**: what to report back

### Review prompt template

domain-reviewer prompts MUST include:

1. **What was changed**: list of files
2. **What to review for**: specific concerns (architecture, billing, i18n, etc.)
3. **Edit policy**: "Do not edit files. Report findings only."

## Parent responsibilities

The parent session MUST:

1. **Decompose** before delegating — don't forward the user's request wholesale
2. **Scope** each worker's task precisely
3. **Choose context** — fork or fresh per worker
4. **Synthesize** all worker outputs into one coherent result
5. **Resolve** contradictions between workers
6. **Validate** the final result (run commands, read files — but NEVER edit)
7. **Report** to the user: what was delegated, what each worker did, what was validated

The parent MUST NOT:

- Edit, write, or delete source files — ever
- Accept worker output without review
- Leave the user with multiple disconnected reports
- Skip the review step for multi-file changes

## Escalation

If a worker fails:
1. Retry once with a narrower prompt or different context strategy
2. If it fails again, delegate to `worker` (builtin) with the failure context included
3. Never silently drop a failed worker's scope
4. Never fall back to editing files yourself — always delegate

## Pre-built chains

| Chain | Steps | When to use |
|---|---|---|
| `scout-implement-review` | scout → worker → domain-reviewer | Single-layer features where scout context helps |
| `implement-test-review` | worker → qa-worker → domain-reviewer | Known scope that needs implementation + tests + review |

For **cross-layer parallel work** (frontend + backend simultaneously), don't use chains. Use:

```
subagent({
  tasks: [
    { agent: "frontend-worker", task: "..." },
    { agent: "backend-worker", task: "..." }
  ],
  concurrency: 2
})
```

Then follow up with `domain-reviewer` and `qa-worker` sequentially.
