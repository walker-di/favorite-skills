---
name: use-browser
description: "Use Playwright for browser investigation, reproduction, verification, and debugging. Supports three browse modes: headless, headed, and user-browser. Use when the task requires interacting with a real browser, inspecting UI behavior, reproducing auth-dependent issues, or debugging flows that are hard to validate from code alone."
---

# Use Browser

Use this skill when browser execution is needed.

All three browse modes use **Playwright**.

A core practice for this skill is to take screenshots as evidence. Screenshots help with verification, debugging, sharing findings, and backward comparison across runs.

## Browse modes

### 1. headless

Use for:
- fast checks
- CI-like verification
- scripted reproduction
- screenshots and DOM inspection without opening a visible window

Prefer `headless` when:
- authentication is not the hard part
- the flow is deterministic
- speed matters more than manual observation

### 2. headed

Use for:
- visual debugging
- animations, focus, timing, and interaction issues
- cases where seeing the browser helps understand failures

Prefer `headed` when:
- the issue is visual or timing-sensitive
- you need to watch the flow run
- headless behavior differs from visible browser behavior

### 3. user-browser

Use for:
- controlling the user’s real browser with Playwright
- debugging flows that require existing user state
- auth/session-specific issues
- reproductions that depend on real cookies, extensions, certs, or local browser context

This is especially useful for:
- debugging with specific authentication already present
- SSO flows
- enterprise login
- issues that only happen in the user’s established browser session

`user-browser` is the newest/most specialized option. Prefer it when browser state is the key constraint.

## Mode selection guidance

Choose the lightest mode that can answer the question:

- Start with **headless** for quick validation
- Move to **headed** if visibility matters
- Move to **user-browser** if authenticated/user-specific state is required

## Workflow

1. Clarify the goal:
   - reproduce a bug
   - inspect a UI flow
   - verify a fix
   - debug auth/session behavior
2. Pick the browser mode.
3. Use Playwright to navigate and interact.
4. Capture evidence:
   - page state
   - screenshots
   - console errors
   - network observations if relevant
5. Prefer screenshots at meaningful checkpoints:
   - initial state
   - before a key interaction
   - after a key interaction
   - error state
   - final state
6. Report findings clearly.

## Screenshot practice

Treat screenshots as a default, not an afterthought.

Take screenshots for:
- important screens and transitions
- before/after comparisons
- error messages and broken states
- successful completion states
- visual regressions or layout issues

Use screenshots to support:
- evidence in reports
- backward comparison against earlier runs
- confirming whether a fix actually changed visible behavior
- communicating findings to the user without rerunning the flow

When useful, name or organize screenshots by step, for example:
- `01-initial.png`
- `02-before-submit.png`
- `03-after-submit.png`
- `04-error-state.png`

If the flow is long, prefer a small set of meaningful screenshots over a noisy dump.

## Guardrails

- Use **Playwright** for all browser modes.
- Be explicit about which mode you chose and why.
- Prefer `user-browser` only when real user state is necessary.
- Avoid unnecessary login automation when `user-browser` is a better fit.
- Treat authenticated sessions and sensitive browser state carefully.
- Take screenshots by default unless the user explicitly says they are unnecessary.
- Be careful not to capture or expose sensitive information in screenshots.
- If the task turns into implementation, switch from investigation to implementation explicitly.

## Report format

When reporting back, include:

```markdown
## Browser Run Summary

**Mode**: headless | headed | user-browser
**Reason**: <why this mode was chosen>

### What I did
- ...

### What I observed
- ...

### Evidence
- screenshots with brief labels or step names
- console errors
- relevant page behavior
- notes on before/after visual comparison when applicable

### Conclusion
- ...
```

## Examples

- “Use browser in `headless` mode to verify the signup form works.”
- “Use browser in `headed` mode to debug the flaky modal interaction.”
- “Use `user-browser` mode to debug the SSO issue with my authenticated session.”
