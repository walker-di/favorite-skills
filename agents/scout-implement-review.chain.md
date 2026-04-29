---
name: scout-implement-review
description: Scout then implement then review. Use for single-layer features where scout context helps the worker.
---

## scout
output: scout-report.md

Investigate the codebase for: {task}

Find relevant files, architecture, existing patterns, and constraints. Return a compressed context report.

## worker
output: implementation-report.md

Goal: {task}

Scout report:
{previous}

Implement the changes. Follow clean architecture conventions. Summarize what you changed.

## domain-reviewer
output: review-report.md

Review changes for: {task}

Implementation report:
{previous}

Check for clean architecture violations, dependency rule breaches, Svelte 5 compliance, i18n. Do not edit files. Report findings only.
