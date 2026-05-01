---
name: pi-subagents-custom-manager
description: Maintain the custom pi-subagents fork safely across origin/upstream, preserve local customization patches, evaluate upstream PR branches before merge, and troubleshoot unstable parallel subagent behavior.
---

# pi-subagents-custom-manager

Use this skill when working on the custom fork at:

- Local repo: `/Users/walker/Documents/Dev/favorite-skills/pi-subagents-custom`
- Fork remote: `origin git@github.com:walker-di/pi-subagents-custom.git`
- Upstream remote: `upstream git@github.com:nicobailon/pi-subagents.git` (push disabled)

## When to use

Use this skill for:

- Routine maintenance of the custom `pi-subagents` fork
- Syncing fork branches with upstream safely
- Preserving and reapplying local customization patches
- Anticipating upstream changes by testing upstream PR/topic branches early
- Preparing clean origin PR branches from local custom work
- Troubleshooting unstable parallel subagent behavior and deciding whether issues are code, config, or environment

Do not use this skill for unrelated project coding tasks.

## Safety rules (non-negotiable)

1. Never push to `upstream`. Treat `upstream` as read-only.
2. Always inspect `git status --short --branch` before and after any operation.
3. Create a branch before changing code, rebasing, or merging.
4. Keep `origin` and `upstream` concepts distinct:
   - `origin/*` is the custom fork state.
   - `upstream/*` is the source project state.
5. Protect local custom patches before sync operations using backup branches/tags.
6. If the working tree is dirty and the task is risky (rebase/cherry-pick/merge), stash or commit to a throwaway branch first.
7. Prefer fast-forward updates where possible; use merge or rebase intentionally and report which strategy was used.
8. Never delete local customization history without explicit user approval.

## Standard command setup

Run from any shell using explicit path:

```bash
REPO="/Users/walker/Documents/Dev/favorite-skills/pi-subagents-custom"
cd "$REPO"
```

Quick remote sanity check:

```bash
git remote -v
# Expect:
# origin   git@github.com:walker-di/pi-subagents-custom.git (fetch/push)
# upstream git@github.com:nicobailon/pi-subagents.git (fetch)
# upstream DISABLED (push)
```

## Routine maintenance commands

### 1) Baseline status

```bash
git status --short --branch
git branch -vv
git log --oneline --decorate --graph -n 20
```

### 2) Fetch latest refs

```bash
git fetch --all --prune
git fetch upstream --prune
git fetch origin --prune
```

### 3) Compare local/main, origin/main, upstream/main

```bash
git rev-list --left-right --count upstream/main...main
git rev-list --left-right --count origin/main...main
git log --oneline --decorate main..upstream/main
git log --oneline --decorate upstream/main..main
```

### 4) Create safety backups before sync

```bash
TS="$(date +%Y%m%d-%H%M%S)"
git branch "backup/pre-sync-$TS"
git tag "backup-pre-sync-$TS"
```

### 5) Sync strategy options

- Merge upstream into current branch:

```bash
git checkout main
git merge --no-ff upstream/main
```

- Rebase custom branch onto upstream:

```bash
git checkout main
git rebase upstream/main
```

- Cherry-pick selected upstream commits:

```bash
git checkout -b integrate/upstream-picks-<topic> main
git cherry-pick <sha1> <sha2>
```

### 6) Push to custom fork (`origin`) only

```bash
git push origin main
git push origin <branch-name>
git push origin --tags
```

## Workflow: patch local customizations safely

Use this when local custom behavior must survive upstream changes.

1. Refresh and branch:

```bash
git fetch --all --prune
git checkout main
git pull --ff-only origin main
git checkout -b custom/<topic>
```

2. Implement only scoped customizations.
3. Commit in logical units.
4. Capture patch queue for portability:

```bash
git format-patch --stdout upstream/main..custom/<topic> > ".git/custom-<topic>.patches.mbox"
```

5. Validate tests (see test section).
6. Merge/rebase `custom/<topic>` into integration branch and push to `origin`.
7. Keep a recovery pointer:

```bash
git branch "backup/custom-<topic>-$(date +%Y%m%d-%H%M%S)" custom/<topic>
```

## Workflow: evaluate upstream PR/topic branches before merge

Use this to anticipate upstream changes (for example `upstream/feat/...`) and detect custom patch breakage early.

### A) Evaluate existing upstream remote branch

```bash
git fetch upstream --prune
git checkout -b eval/upstream-feat-<topic> upstream/feat/<topic>
```

Then compare against your custom baseline:

```bash
git log --oneline --decorate --left-right main...eval/upstream-feat-<topic>
git diff --stat main...eval/upstream-feat-<topic>
```

Apply your custom patch stack (merge/rebase/cherry-pick as appropriate), run tests, document conflicts.

### B) Evaluate a GitHub PR by number

```bash
git fetch upstream pull/<PR_NUMBER>/head:pr/<PR_NUMBER>
git checkout pr/<PR_NUMBER>
```

Then create evaluation branch:

```bash
git checkout -b eval/pr-<PR_NUMBER>
```

Run the same compare + test workflow before deciding to merge into custom branches.

## Integration workflow (upstream sync + custom patches)

Use this when upstream moved and custom patches must be retained.

1. Backup current state (branch + tag).
2. Create integration branch from latest upstream main:

```bash
git fetch upstream --prune
git checkout -b integrate/upstream-$(date +%Y%m%d) upstream/main
```

3. Reapply custom patch queue:
   - Option 1: `git cherry-pick` selected custom commits
   - Option 2: `git rebase --onto` for whole custom line
   - Option 3: `git am` from generated mbox patch queue
4. Resolve conflicts and run full validation.
5. Compare to previous `main` for regression scope:

```bash
git diff --stat main...HEAD
git log --oneline --decorate main..HEAD
```

6. If validated, fast-forward or merge into `main`.
7. Push only to `origin`.

## Testing and validation commands (from package scripts)

Run in `/Users/walker/Documents/Dev/favorite-skills/pi-subagents-custom`:

```bash
npm test
npm run test:unit
npm run test:integration
npm run test:all
```

Script details:

- `test`: runs unit tests
- `test:unit`: `node --experimental-strip-types --test test/unit/*.test.ts`
- `test:integration`: `node --experimental-transform-types --import ./test/support/register-loader.mjs --test test/integration/*.test.ts`
- `test:all`: runs unit then integration

Recommended validation order after sync or patching:

1. `npm run test:unit`
2. `npm run test:integration`
3. `npm run test:all` (for release confidence)

## Install, link, and development notes

This repository is a Node-based Pi extension package (`pi.extensions`, `pi.skills`, `pi.prompts` in `package.json`).

- Standard install for users:

```bash
pi install npm:pi-subagents
```

- Optional companion for parent-child coordination:

```bash
pi install npm:pi-intercom
```

- Local fork development:
  - Prefer testing in a dedicated branch.
  - Keep `origin/main` stable; use feature/integration branches for experiments.
  - If testing local package behavior in Pi, install from local path or package tarball in a controlled environment, then revert to stable install once validated.

## Troubleshooting unstable parallel subagents

When parallel runs are flaky, collect evidence before code edits:

1. Verify runtime health:

```text
/subagents-status
/subagents-doctor
```

2. Check whether failures are deterministic:
   - Re-run with lower concurrency.
   - Compare `fresh` vs `fork` context.
3. Confirm environment and limits:
   - model/provider quota or rate-limit errors
   - missing companion tooling (`pi-intercom`, optional MCP adapters)
4. Validate with integration tests:

```bash
npm run test:integration
```

5. If parallel-only regressions appear after upstream sync, bisect between last known-good tag and current head.

## Final response checklist for future uses of this skill

Always end with:

- Current branch and cleanliness (`git status --short --branch`)
- Remotes verified (`origin`/`upstream`) and confirmation that no upstream push occurred
- Upstream delta summary (what changed, commit/PR references)
- Local customization patch status (preserved/reapplied/conflicts)
- Backup artifacts created (branches/tags/patch files)
- Validation commands run and pass/fail results
- What was pushed to `origin` (if anything)
- Explicit next safe action (for example: open PR, run integration tests, or continue conflict resolution)
