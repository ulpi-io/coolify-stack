# Founder Review Rubric

Use this reference when `plan-founder-review/SKILL.md` needs the scoring, mode-selection, and verdict rules without carrying them inline on every invocation.

## Mode Selection

`FULL` review:

- 5 or more tasks
- `EXPANSION` mode
- explicit `--full`

`QUICK` review:

- fewer than 5 tasks
- `HOLD` or `REDUCTION` mode
- explicit `--quick`

`QUICK` reviews run Sections 1 through 3 only.

`FULL` reviews run all 6 checklist sections.

## Section Status

Score every reviewed section as:

- `PASS`: no blocks, at most 1 concern
- `WARN`: no blocks, 2 or more concerns
- `FAIL`: one or more blocks

## Verdict Rules

- `APPROVE`: 0 blocks and 0-2 total concerns
- `REVISE`: 0 blocks and 3 or more total concerns
- `REJECT`: 1 or more blocks

## Finding Classes

### BLOCK

Use for execution-stopping defects such as:

- phantom file path to modify
- building functionality that already exists
- markdown/JSON drift that changes execution meaning
- missing critical dependency in the DAG
- contradictory architecture or contract definition
- public contract drift on a promised SQL, API, or CLI surface
- placeholder semantic gap that lets a structural rewrite "pass" while remaining wrong
- critical risk with no mitigation
- zero test coverage on a security-sensitive path

### CONCERN

Use for plan problems that should be fixed before execution but are not instant hard stops, such as:

- mode mismatch
- unnecessary scope
- missed reuse
- hidden prerequisites
- vague mitigations
- missing edge-case criteria
- test coverage gaps
- over-constrained DAG
- wrong agent assignment
- XL task that should be decomposed
- P0 task with dependencies
- hidden write-scope overlap

### OBSERVATION

Use for non-blocking improvements such as:

- reuse opportunity
- alternative implementation approach
- parallelism improvement
- naming suggestion
- additional edge case worth considering

## Report Shape

Render:

```md
## Founder Review: <Plan Title>

Plan: <path> | Mode: FULL/QUICK | Tasks: N

### Verdict: APPROVE / REVISE / REJECT

| Section | Status | Findings |
|---------|--------|----------|
| 1. Codebase Reality | PASS/WARN/FAIL | ... |
| 2. Scope & Strategy | PASS/WARN/FAIL | ... |
| 3. Architecture & Integration | PASS/WARN/FAIL | ... |
| 4. Risk & Recovery | PASS/WARN/FAIL | ... |
| 5. Test Coverage | PASS/WARN/FAIL | ... |
| 6. Execution Feasibility | PASS/WARN/FAIL | ... |

### Blocking Issues
...

### Concerns
...

### Observations
...

### Required Plan Changes
...
```

For `QUICK` mode, omit Sections 4 through 6 from the section table.

## Forked Review Rationale

`plan-founder-review` is a strong candidate for:

- `context: fork`
- `agent: general-purpose`
- `effort: high`

Why:

- it is read-heavy analysis
- it benefits from isolated reasoning budget
- it should not mutate the working plan during review
- it does not require mid-process user interaction

Relevant runtime anchors:

- `claude-code-source/src/skills/loadSkillsDir.ts`
- `claude-code-source/src/tools/SkillTool/SkillTool.ts`
- `claude-code-source/src/utils/forkedAgent.ts`
