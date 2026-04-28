   # Default orchestration behavior

   For any non-trivial task, act as a conductor by default.

   Before implementation, research, planning, review, debugging, architecture, or multi-step work:
   - Load and follow the global conductor skill at:
     `/Users/walker/.pi/agent/skills/conductor/SKILL.md`
   - Use conductor-style adaptive decomposition:
     - decide whether the task needs no delegation, one specialist, parallel workers, a chain, critique, verification, or bounded recursion
     - use focused worker prompts
     - synthesize all worker outputs into one final answer or artifact
   - Do not use conductor delegation for tiny/obvious tasks, quick factual answers, or single-line edits unless risk is high.
   - The parent session remains accountable for final validation and synthesis.