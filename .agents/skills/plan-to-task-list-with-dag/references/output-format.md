# Plan Output Format

Use this reference when rendering the final markdown and JSON artifacts for `plan-to-task-list-with-dag`.

## Required Markdown Sections

Every saved plan should include:

1. `# Plan: <title>`
2. `## Overview`
3. `## Scope Challenge`
4. `## Prerequisites`
5. `## Non-Goals`
6. `## Contracts`
7. `## Existing Code Leverage`
8. `## Tasks`
9. `## Failure Modes`
10. `## Ship Cut`
11. `## Test Coverage Map`
12. `## Execution Summary`
13. `## Task Dependencies`

## Required Task Fields In Markdown

Each task must include:

- `### TASK-NNN: <title>`
- clear description
- `**Type:**`
- `**Effort:**`
- `**Agent:**`
- `**Priority:**`
- `**Depends on:**` when applicable
- `**Acceptance Criteria:**`

Prefer also including:

- `writeScope`
- `validateCommand`
- integration notes when shared surfaces are involved

## Agent Selection Reference

Use the agent whose domain best matches the task's primary technology:

| Agent | Use For |
| --- | --- |
| `laravel-senior-engineer` | Laravel, PHP, Eloquent |
| `nextjs-senior-engineer` | Next.js App Router, RSC, Server Actions |
| `react-vite-tailwind-engineer` | React, Vite, Tailwind, TypeScript frontends |
| `express-senior-engineer` | Express.js, Node.js APIs, middleware |
| `nodejs-cli-senior-engineer` | Node.js CLI tools, commander.js |
| `python-senior-engineer` | Python, Django, data pipelines |
| `fastapi-senior-engineer` | FastAPI specifically, async DB, JWT auth |
| `go-senior-engineer` | Go backends, services, APIs |
| `go-cli-senior-engineer` | Go CLI tools, cobra, viper |
| `rust-senior-engineer` | Rust systems, storage engines, query layers, CLIs |
| `ios-macos-senior-engineer` | Swift, SwiftUI, Xcode, SPM, AVFoundation, StoreKit |
| `expo-react-native-engineer` | Expo, React Native mobile apps |
| `devops-aws-senior-engineer` | AWS, CDK, CloudFormation, Terraform |
| `devops-docker-senior-engineer` | Docker, Docker Compose, containerization |
| `general-purpose` | Research, docs, orchestration, mixed tasks |

## Review Values

Supported review values:

- `claude`
- `codex`
- `kiro`
- `all`
- `none`

The selected value becomes the default review posture for execution unless a task explicitly overrides it.

## Required JSON Shape

The JSON file must represent the same plan as markdown and should include:

- plan metadata
- prerequisites
- non-goals
- contracts
- tasks array
- dependency map
- critical path or derived execution summary

Each task object should include at least:

```json
{
  "id": "TASK-001",
  "title": "Task title",
  "description": "What the task does",
  "priority": "P0",
  "type": "feature",
  "effort": "M",
  "agent": "general-purpose",
  "dependsOn": [],
  "acceptanceCriteria": [
    "Success case",
    "Failure or edge case"
  ],
  "filesToModify": [],
  "filesToCreate": [],
  "writeScope": [],
  "validateCommand": "command to validate task completion",
  "review": "claude"
}
```

## Dependency Rules

- every task id in markdown must appear in JSON
- every dependency target must exist
- no circular dependencies
- no dependency should be added just because two tasks are conceptually related

Only add dependencies for:

- file overlap
- data flow
- API contract
- shared integration surface
- bootstrap ordering
- capability-provider ordering

## Lint Checklist

Before finishing, confirm:

- priorities use only `P0`, `P1`, `P2`, `P3`
- task ids use `TASK-NNN`
- no `[PLAN]` markers are written to disk
- markdown and JSON task counts match
- acceptance criteria are measurable
- at least one failure or edge path is covered where applicable
- new file creation tasks have explicit export or registration ownership
- public-surface work includes wrong-shape, wrong-routing, or failure-path validation where relevant

## When To Use Examples

Use `examples.md` only when:

- the requested plan shape is ambiguous
- you need a comparable feature size example
- you want to mirror a previously successful presentation style

Do not load examples by default.
