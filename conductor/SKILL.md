---
name: conductor
description: Dynamically orchestrate multiple specialist agents for complex, multi-domain tasks using Sakana Conductor/Fugu-inspired workflows. Use when a request benefits from adaptive decomposition, parallel specialist work, critique/refinement loops, bounded recursion, or a unified synthesis from several agents rather than a single linear response.
---

# Conductor

Use this skill when a task is too broad, high-stakes, interdisciplinary, or uncertain for a single-pass answer and would benefit from **adaptive multi-agent orchestration**.

This skill adapts ideas from Sakana AI's Fugu beta and the Conductor paper:

- Sakana Fugu: https://sakana.ai/fugu-beta/
- Nielsen et al., "Learning to Orchestrate Agents in Natural Language with the Conductor" (arXiv:2512.04388): https://arxiv.org/abs/2512.04388

The core idea is to act as a **meta-agent**: dynamically divide the user's task, assign focused natural-language subtasks to appropriate workers, control what each worker can see from previous work, then synthesize and verify the final answer.

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

4. **Difficulty-adaptive compute**
   - Simple tasks get 1-2 calls.
   - Moderate tasks get 2-4 specialists.
   - Hard/high-stakes tasks may use parallel exploration plus verifier/synthesizer loops.
   - Cap the workflow before starting; do not spawn open-ended agents.

5. **Verification before synthesis**
   - Prefer at least one explicit verifier/critic for implementation plans, risky claims, architecture choices, migrations, security, or generated code.
   - The parent session owns final judgment; do not blindly concatenate worker outputs.

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
- Always synthesize into one final answer or one canonical artifact. Do not leave the user with multiple disconnected reports.
- Disclose delegation in the final response: which workers ran and what they contributed.
- If a worker fails, retry once with a narrower prompt or handle the missing section yourself with the failure clearly disclosed.

## Workflow

### 1. Clarify and classify

If requirements are ambiguous in a way that affects scope, ask concise clarifying questions before spawning workers. If the user says to proceed, document assumptions.

Classify the task:

- **Answer/research**: gather evidence, compare options, synthesize answer.
- **Planning**: produce an implementation or migration plan only.
- **Implementation**: edit code, then verify.
- **Review/QA**: inspect artifacts and find defects.
- **Creative/design**: generate concepts, variants, critique, converge.

### 2. Build the worker pool

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
```

#### B. Parallel independent attempts

Use for research, debugging hypotheses, design alternatives, or high-uncertainty tasks.

```text
Step 1: workers A/B/C investigate independently with no cross-visibility
Step 2: parent compares agreements/conflicts
Step 3: optional verifier checks synthesis
```

#### C. Sequential chain

Use when later work depends on earlier output.

```text
Step 1: investigator maps facts
Step 2: planner uses investigator report
Step 3: implementer or writer uses plan
Step 4: verifier reviews result
```

#### D. Tree topology

Use when independent branches feed a final integrator.

```text
Step 1: branch workers handle separate domains
Step 2: integrator receives all branch reports
Step 3: parent validates integrator output
```

#### E. Debate / critique / refinement

Use for risky plans, architecture, security, data modeling, or uncertain recommendations.

```text
Step 1: proposer drafts solution
Step 2: critic sees proposal and attacks assumptions
Step 3: proposer or parent revises
Step 4: verifier checks final answer
```

#### F. Bounded recursive correction

Use when verification reveals a concrete gap after synthesis.

```text
Step 1: initial workflow
Step 2: parent identifies gap
Step 3: one targeted recursive worker round on that gap
Step 4: parent updates final synthesis
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

| Step | Worker | Subtask | Access to prior work | Output |
|---|---|---|---|---|
| 1 | <agent> | <focused prompt> | none | <report/patch/etc> |
| 2 | <agent> | <focused prompt> | step 1 | <critique/etc> |
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
subagent({ agent: "<agent>", task: "<prompt>" })
```

```text
subagent({
  tasks: [
    { agent: "<agent-a>", task: "<prompt>", output: "<optional-report-a.md>" },
    { agent: "<agent-b>", task: "<prompt>", output: "<optional-report-b.md>" }
  ],
  concurrency: 2,
  worktree: false
})
```

```text
subagent({
  chain: [
    { agent: "<investigator>", task: "<prompt>" },
    { agent: "<planner>", task: "Use this prior report: {previous}\n\n<prompt>" },
    { agent: "<verifier>", task: "Review this plan/result: {previous}\n\n<prompt>" }
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
- **For UI work**: Test the visible outcome in a browser, capture before/after screenshots, verify responsive behavior across screen sizes, and confirm interactive elements work as intended. If browser validation was not performed, explicitly disclose this limitation.
- Produce one coherent final answer, artifact, or patch summary.

## Suggested worker roles

Choose only roles that the task needs:

- **mapper**: finds relevant files, docs, architecture, constraints.
- **domain specialist**: analyzes a specific layer/domain (frontend, backend, data, infra, security, etc.).
- **planner**: turns findings into a sequenced plan.
- **implementer**: performs scoped edits when authorized.
- **critic**: attacks assumptions, edge cases, architecture violations, and hidden risks.
- **verifier**: checks correctness through tests, commands, browser, or static inspection.
- **synthesizer**: merges reports into a single coherent artifact.

## Patterns to prefer

### Hard implementation task

1. Mapper: locate relevant code and constraints.
2. Planner: propose minimal change sequence.
3. Implementer: make scoped edits.
4. Verifier: run/read tests and inspect for regressions.
5. Parent: final validation and summary.

### Broad implementation planning

If the task specifically asks for `plan_implemention`, use that skill instead. Otherwise:

1. Frontend/domain worker if UI is involved.
2. Backend/domain worker if APIs/data are involved.
3. Tests/validation worker.
4. Parent: unified plan with sequencing, risks, and commands.

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

### Synthesis
- ...

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
- [ ] For UI changes: Browser testing was performed with screenshots, or limitation was explicitly disclosed.
- [ ] One unified final answer/artifact was produced.
- [ ] Delegation and validation are disclosed to the user.

## Notes from the research

- Fugu treats orchestration as an API-compatible layer over a pool of frontier models; the user sees one interface while the system selects roles, subtasks, and collaboration patterns.
- The Conductor paper frames each workflow step as `(worker, natural-language subtask, access_list)`.
- Learned Conductors beat fixed routers/scaffolds partly because they can invent task-specific prompts and topologies instead of choosing from hand-designed templates.
- Effective strategies include independent attempts, planner/solver/verifier chains, final debate/checking rounds, and difficulty-adaptive step counts.
- Randomized worker-pool training suggests orchestration should adapt to available agents and constraints rather than depending on one fixed best model.
- Recursive conductor calls provide test-time scaling, but in this pi skill recursion must be bounded and targeted to avoid runaway delegation.
