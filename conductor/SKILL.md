---
name: conductor
description: Dynamically orchestrate multiple specialist agents for complex, multi-domain tasks using Sakana Conductor/Fugu-inspired workflows. Use when a request benefits from adaptive decomposition, parallel specialist work, critique/refinement loops, bounded recursion, or a unified synthesis from several agents rather than a single linear response.
---

# Conductor

Use this skill when a task is too broad, high-stakes, interdisciplinary, or uncertain for a single-pass answer and would benefit from **adaptive multi-agent orchestration**.

This skill adapts ideas from Sakana AI's Fugu beta and the Conductor paper:

- Sakana Fugu: https://sakana.ai/fugu-beta/
- Nielsen et al., "Learning to Orchestrate Agents in Natural Language with the Conductor" (arXiv:2512.04388): https://arxiv.org/abs/2512.04388

The core idea is to act as a **meta-agent**: dynamically divide the user's task, assign focused natural-language subtasks to appropriate workers, control what each worker can see from previous work, then synthesize and verify the final answer with runtime proof.

## When to use

Use `conductor` when the user asks for or implies any of the following:

- "orchestrate agents", "conductor", "multi-agent", "ensemble", "parallel review", "deep research", "get multiple perspectives"
- a complex implementation touching frontend + backend + tests + architecture
- a broad design/research/problem-solving task where independent perspectives reduce error
- a high-risk change needing critique, verification, or adversarial review
- an ambiguous task where multiple hypotheses should be investigated before choosing a path
- a task that can be decomposed into independent branches and then merged

Do **not** use `conductor` for small, obvious edits, single-file fixes, quick factual answers, or when the user explicitly wants no delegation.

## Conductor principles

1. **Adaptive decomposition over fixed scaffolds**
   - Do not force every task into the same workflow.
   - Choose the topology based on task complexity: single specialist, parallel branches, sequential chain, tree, verifier loop, or bounded recursion.

2. **Natural-language subtask engineering matters**
   - Each worker prompt must be precise, scoped, and role-specific.
   - Ask workers to focus on the part they are best suited for.
   - Include constraints, expected output format, relevant files/docs, and non-goals.

3. **Controlled communication topology**
   - Decide what each worker may see.
   - Use isolation for independent attempts.
   - Share prior outputs only when refinement, critique, synthesis, or verification benefits from them.

4. **Difficulty-adaptive compute + model selection**
   - Simple tasks get 1-2 calls and prefer fast models.
   - Moderate tasks get 2-4 specialists on balanced models.
   - Hard/high-stakes tasks may use stronger models plus verifier/synthesizer loops.
   - Cap the workflow before starting; do not spawn open-ended agents.

5. **Mandatory runtime verification**
   - Every implementation workflow MUST end with a verification step that proves the feature works in the running application.
   - Tests alone are insufficient; runtime evidence is required.
   - The verification step must: (1) start or use the dev server, (2) exercise the implemented feature via curl/API call or browser automation, (3) capture concrete evidence (response body, screenshot, or log output).

6. **Bounded recursion only**
   - If the first synthesized result reveals a major gap, run at most one additional recursive round unless the user authorizes more.
   - Recursive rounds must target the discovered gap, not restart the whole task.

## Hard rules

- You remain the conductor and final accountable agent.
- Before using the `subagent` tool, call `subagent({ action: "list" })` and choose only executable, non-disabled agents.
- Use the `subagent` tool for orchestration.
- Standard execution patterns are single, parallel, and chain subagent calls.
- Do not create subagent worktrees unless the user explicitly requested isolated implementation branches or the selected workflow requires safe parallel code edits.
- If the task is planning/research/review only, worker prompts must say: `Do not implement, edit, write, or delete files.`
- If implementation is authorized, minimize concurrent edits to overlapping files; prefer one implementer and separate reviewers unless using isolated worktrees.
- **MANDATORY RUNTIME VERIFICATION**: Every implementation workflow MUST include a final verification step that provides runtime proof the feature works. A workflow without this step is INCOMPLETE. Use qa-worker with use-browser skill for UI features, or shell commands for API endpoints.
- Never synthesize 'done' without runtime evidence: actual browser interaction, API response capture, or log output proving the implemented feature works in the running application.
- Always synthesize into one final answer or one canonical artifact. Do not leave the user with multiple disconnected reports.
- Disclose delegation in the final response: which workers ran and what they contributed.
- If a worker fails, classify quota/usage-limit failures first; do not treat them as generic worker failures.
- For quota-limited runs, retry with model fallback before prompt rewrites.
- If retries still fail, handle the missing section yourself with the failure clearly disclosed.

## Workflow

### 1. Clarify and classify

If requirements are ambiguous in a way that affects scope, ask concise clarifying questions before spawning workers. If the user says to proceed, document assumptions.

Classify the task:

- **Answer/research**: gather evidence, compare options, synthesize answer.
- **Planning**: produce an implementation or migration plan only.
- **Implementation**: edit code, then verify with runtime proof.
- **Review/QA**: inspect artifacts and find defects.
- **Creative/design**: generate concepts, variants, critique, converge.

### 2. Build the worker pool

#### Model routing defaults (prefer cursor provider)

Pick model by difficulty unless user overrides:

- `simple`: `cursor/gpt-5.4`
- `moderate`: `cursor/claude-4.6-sonnet` or `cursor/gpt-5.4`
- `hard`: `cursor/claude-4.6-sonnet`

Fallback ladder for quota/usage-limit failures (`usage limit`, `team plan`, `insufficient_quota`, `429`) or likely provider/model stalls (`exit 143`, long inactivity after the last tool result, or tiny partial output followed by dead time):
1. `cursor/claude-4.6-sonnet`
2. `cursor/gpt-5.4`
3. `cursor/gemini-2.5-pro`
4. `cursor/gemini-2.5-flash`

Agent defaults:
- `scout`, `planner`, `delegate`, `reviewer`: `cursor/gpt-5.4` or `cursor/claude-4.6-sonnet`
- `frontend-worker`, `backend-worker`, `qa-worker`, `domain-reviewer`: `cursor/claude-4.6-sonnet` or `cursor/gpt-5.4`


Call:

```text
subagent({ action: "list" })
```

Select workers from available executable agents and local skills. If no appropriate specialized subagent exists, use a general coding/research worker with a very specific prompt.

For each candidate worker, note:

- role
- reason selected
- whether it should edit files
- expected output
- context it may read
- prior reports it may see

### 3. Choose a topology

Use the smallest topology that can succeed:

#### A. Single specialist

Use when the task needs one narrow expertise area plus parent synthesis.

```text
Step 1: specialist investigates or implements
Step 2: parent validates and responds
Step 3: MANDATORY runtime verification (for implementation tasks)
```

#### B. Parallel independent attempts

Use for research, debugging hypotheses, design alternatives, or high-uncertainty tasks.

```text
Step 1: workers A/B/C investigate independently with no cross-visibility
Step 2: parent compares agreements/conflicts
Step 3: optional verifier checks synthesis
Step 4: MANDATORY runtime verification (for implementation tasks)
```

#### C. Sequential chain

Use when later work depends on earlier output.

```text
Step 1: investigator maps facts
Step 2: planner uses investigator report
Step 3: implementer uses plan
Step 4: verifier reviews result
Step 5: MANDATORY runtime verification with evidence capture
```

#### D. Tree topology

Use when independent branches feed a final integrator.

```text
Step 1: branch workers handle separate domains
Step 2: integrator receives all branch reports
Step 3: parent validates integrator output
Step 4: MANDATORY runtime verification (for implementation tasks)
```

#### E. Debate / critique / refinement

Use for risky plans, architecture, security, data modeling, or uncertain recommendations.

```text
Step 1: proposer drafts solution
Step 2: critic sees proposal and attacks assumptions
Step 3: proposer or parent revises
Step 4: verifier checks final answer
Step 5: MANDATORY runtime verification (for implementation tasks)
```

#### F. Bounded recursive correction

Use when verification reveals a concrete gap after synthesis.

```text
Step 1: initial workflow
Step 2: parent identifies gap
Step 3: one targeted recursive worker round on that gap
Step 4: parent updates final synthesis
Step 5: MANDATORY runtime verification with evidence
```

### 4. Write an explicit coordination spec

Before spawning workers, create a compact internal coordination spec equivalent to the Conductor paper's `model_id`, `subtasks`, and `access_list`.

Use this shape in your notes/reasoning, and optionally in an artifact when useful:

```markdown
## Conductor Coordination Spec

- Goal: <user goal>
- Assumptions: <assumptions>
- Max rounds: <N>
- Edit policy: <no edits | parent edits only | one implementer edits | worktree isolation>
- Verification method: <qa-worker browser | shell commands | API testing>

| Step | Worker | Subtask | Access to prior work | Output |
|---|---|---|---|---|
| 1 | <agent> | <focused prompt> | none | <report/patch/etc> |
| 2 | <agent> | <focused prompt> | step 1 | <critique/etc> |
| N | qa-worker | Runtime verification | all | <evidence/screenshots> |
```

Communication/access options:

- `none`: independent attempt; do not include prior worker outputs.
- `selected`: include only named prior outputs relevant to the subtask.
- `all`: include all prior reports, for synthesis or verification.

### 5. Prompt workers with strict role constraints

Every worker prompt should include:

```text
You are a specialist worker in a conductor-orchestrated workflow.
Role: <role>
Goal: <overall user goal>
Your subtask: <specific subtask>
Scope boundaries: <what to include/exclude>
Edit policy: <whether edits are allowed>
Context/access: <none/selected/all prior reports>
Output format: <required report/checklist/patch summary/etc>
If uncertain, state assumptions, risks, and what evidence would resolve them.
```

For planning/research/review-only workflows, include exactly:

```text
Do not implement, edit, write, or delete files.
```

For implementation workers, include:

```text
Implement only the scoped changes. Preserve existing architecture and project instructions. Report changed files and validation performed. Do not broaden scope.
```

### 6. Execute with `subagent`

Prefer parallel mode for independent workers and chain mode for dependent workflows.

Examples:

```text
subagent({ agent: "<agent>", task: "<prompt>", model: "<selected-model>" })
```

```text
subagent({
  tasks: [
    { agent: "<agent-a>", task: "<prompt>", model: "<selected-model>", output: "<optional-report-a.md>" },
    { agent: "<agent-b>", task: "<prompt>", model: "<selected-model>", output: "<optional-report-b.md>" }
  ],
  concurrency: 2,
  worktree: false
})
```

```text
subagent({
  chain: [
    { agent: "<investigator>", task: "<prompt>", model: "<selected-model>" },
    { agent: "<planner>", task: "Use this prior report: {previous}\n\n<prompt>", model: "<selected-model>" },
    { agent: "<implementer>", task: "Use this plan: {previous}\n\n<prompt>", model: "<selected-model>" },
    { agent: "qa-worker", task: "Verify implementation works: use-browser skill to test the feature and capture screenshots: {previous}\n\n<prompt>", model: "cursor/claude-4.6-sonnet" }
  ]
})
```

```text
subagent({ action: "status", id: "..." })
subagent({ action: "interrupt", id: "..." })
subagent({ action: "doctor" })
```

### 7. Validate and synthesize

After receiving reports:

- Identify consensus, contradictions, missing evidence, and unsupported claims.
- Resolve contradictions yourself by reading files/running commands when necessary.
- For code-impacting tasks, run the smallest meaningful validation commands yourself unless a worker already did and the result is trustworthy.
- **MANDATORY RUNTIME VERIFICATION**: For ANY implementation task, you MUST include a verification step that exercises the feature in the running application and captures evidence. This can be done by qa-worker using use-browser skill or by direct shell commands.
- Produce one coherent final answer, artifact, or patch summary.

## Suggested worker roles

Choose only roles that the task needs:

- **mapper**: finds relevant files, docs, architecture, constraints.
- **domain specialist**: analyzes a specific layer/domain (frontend, backend, data, infra, security, etc.).
- **planner**: turns findings into a sequenced plan.
- **implementer**: performs scoped edits when authorized.
- **critic**: attacks assumptions, edge cases, architecture violations, and hidden risks.
- **verifier**: checks correctness through tests, commands, browser, or static inspection.
- **runtime-verifier**: uses qa-worker or shell commands to prove the feature works in the running application.
- **synthesizer**: merges reports into a single coherent artifact.

## Patterns to prefer

### Hard implementation task

1. Mapper: locate relevant code and constraints.
2. Planner: propose minimal change sequence.
3. Implementer: make scoped edits.
4. Verifier: run/read tests and inspect for regressions.
5. **MANDATORY Runtime Verifier**: use qa-worker with browser automation or shell commands to exercise the feature and capture evidence.
6. Parent: final validation and summary.

### Broad implementation planning

If the task specifically asks for `plan_implemention`, use that skill instead. Otherwise:

1. Frontend/domain worker if UI is involved.
2. Backend/domain worker if APIs/data are involved.
3. Tests/validation worker.
4. **Runtime verification worker**: plan how to verify the implementation works in the running application.
5. Parent: unified plan with sequencing, risks, and verification commands.

### Deep research / paper study

1. Source summarizer: extract claims and mechanisms from primary sources.
2. Critic: identify limitations, assumptions, and what is not proven.
3. Applicator: translate concepts into the local task/domain.
4. Parent: unified synthesis with citations/links and practical guidance.

### Review / QA

1. Independent reviewer(s): inspect separate layers or hypotheses.
2. Critic/verifier: check the most likely failure modes.
3. Parent: prioritized findings with evidence and recommended fixes.

## Output formats

### Final response for delegated conductor work

```markdown
## Conductor Result

### Workflow
n. <worker/role> — <what it did>
n+1. runtime-verifier — captured evidence proving feature works

### Synthesis
- ...

### Runtime Evidence
- <screenshots, API responses, log output proving the feature works>

### Key Decisions
- ...

### Validation
- ...

### Risks / Open Questions
- ...

### Next Step
- ...
```

### Optional saved artifact

When the output is substantial, save one canonical artifact, for example:

- `.pi/plans/<topic>-conductor-plan.md`
- `.pi/reports/<topic>-conductor-report.md`
- `.pi/reviews/<topic>-conductor-review.md`

Do not create multiple competing final artifacts unless the user asks for alternatives.

## Quality checklist

Before finalizing, verify:

- [ ] The workflow topology matched the task difficulty.
- [ ] Worker prompts were focused and role-specific.
- [ ] Access to prior work was intentionally controlled.
- [ ] Planning-only workers did not edit files.
- [ ] Implementation workers, if any, stayed in scope.
- [ ] Contradictions between workers were resolved.
- [ ] Claims are grounded in files, command output, or cited sources.
- [ ] **MANDATORY**: For implementation tasks, runtime verification was performed with concrete evidence (browser screenshots, API responses, or log output).
- [ ] A workflow cannot be considered complete without runtime proof that the feature works in the running application.
- [ ] One unified final answer/artifact was produced.
- [ ] Delegation and validation are disclosed to the user.

## Notes from the research

- Fugu treats orchestration as an API-compatible layer over a pool of frontier models; the user sees one interface while the system selects roles, subtasks, and collaboration patterns.
- The Conductor paper frames each workflow step as `(worker, natural-language subtask, access_list)`.
- Learned Conductors beat fixed routers/scaffolds partly because they can invent task-specific prompts and topologies instead of choosing from hand-designed templates.
- Effective strategies include independent attempts, planner/solver/verifier chains, final debate/checking rounds, and difficulty-adaptive step counts.
- Randomized worker-pool training suggests orchestration should adapt to available agents and constraints rather than depending on one fixed best model.
- Recursive conductor calls provide test-time scaling, but in this pi skill recursion must be bounded and targeted to avoid runaway delegation.
