---
name: implement-test-review
description: Implement then test then review. Use when the change scope is known and needs validation.
---

## worker
output: implementation-report.md

Implement: {task}

Follow clean architecture conventions. Summarize what you changed and which files belong to which layer.

## qa-worker
output: qa-report.md

Write tests and validate for: {task}

Implementation report:
{previous}

Add tests at correct layers. Run validation. Report results.

## domain-reviewer
output: review-report.md

Review all changes for: {task}

QA report:
{previous}

Check for architecture violations, testing gaps, boundary leaks. Do not edit files. Report findings only.
