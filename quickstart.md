# Context Engineering Quick Start

Get a working AI context system set up in ~2 hours. Focus on what generates the most failures first — you can add depth later.

→ For the full pattern library see [deep-dive.md](deep-dive.md)  
→ For copy-pasteable templates see [examples/](examples/)

---

## Before you start: diagnose first

Don't build everything at once. Identify which areas are generating the most AI context failures in your codebase, then target those first.

Common failure areas:

| Failure | What's missing |
|---------|---------------|
| Agent invents API routes or request shapes | OpenAPI spec not linked |
| Agent duplicates existing services/utilities | Service pattern reference not linked |
| Agent misses side effects in event-driven flows | Event catalog not present |
| Agent uses wrong naming conventions | Naming conventions not in rules |
| Agent re-explains things you told it last session | CLAUDE.md is too long to stay in context |
| Agent changes files outside the task scope | No explicit `files-allowed` discipline |

Start with your top two or three. Don't build a context library — build answers to specific failures.

---

## Phase 1: Foundation (30 min)

### 1. Create CLAUDE.md — short and navigational

CLAUDE.md is loaded at every session start. Keep it short — it should be a map to depth, not depth itself. Long CLAUDE.md files are partially read, partially ignored, and hard to maintain.

The pattern that works: a linked table of docs, a short critical rules section, and nothing else.

```markdown
# CLAUDE.md

## Project Overview

[One paragraph: what the system is, main packages, core tech stack]

## Documentation (read on demand)

| Doc | Contents |
|-----|----------|
| [architecture.md](docs/architecture.md) | System overview, data flow, integration points |
| [coding-standards.md](docs/coding-standards.md) | Patterns, naming, code organisation |
| [testing.md](docs/testing.md) | TDD requirements, test patterns, frameworks |
| [openapi-bundle.yaml](api/openapi/openapi-bundle.yaml) | All API routes, request/response schemas |
| [event-catalog.json](docs/event-catalog.json) | Events, payloads, emitters, consumers |
| [service-patterns.md](docs/service-patterns.md) | When to use each service pattern, with examples |

## Critical Rules

- [Two or three things that will cause failures if violated — not general advice]
- [Example: "API tests must run in Docker — host tests skip DB integration and give false-green results"]
- [Example: "Update the OpenAPI spec before committing any API route changes"]

## Known Constraints

- [Specific technical gotchas that aren't obvious from the code]
- [Example: "Branch named `feature/123` blocks creation of `feature/123/sub` — use flat names"]
```

See [examples/CLAUDE.md](examples/CLAUDE.md) for a fuller template.

**What goes in CLAUDE.md vs elsewhere:**

| CLAUDE.md | `.claude/rules/` | `docs/` |
|-----------|-----------------|---------|
| Project overview | Single-topic conventions | Architecture, flows, patterns |
| Linked doc table | Path-scoped file rules | API specs, schemas |
| Critical rules (3–5 max) | Package manager rules | Glossary, ADRs |
| Known constraints | Test runner rules | Generated artifacts |

---

### 2. Create `.claude/rules/` for path-scoped conventions

Rules are markdown files that load only when Claude opens a matching file path. This keeps irrelevant conventions out of context and avoids bloating every session.

```
.claude/
└── rules/
    ├── git-workflow.md          # no paths — loads every session
    ├── naming-conventions.md    # paths: src/**
    ├── api-conventions.md       # paths: api/src/**
    └── openapi-sync.md          # paths: api/src/**
```

Rule format:

```markdown
---
description: One-line summary shown in /memory list
paths:
  - "api/src/**"
  - "api/test/**"
---

## Rule Title

Your instruction here. One topic per file. Keep it short — 5–10 lines is ideal.
```

Rules to create for most projects:
- `git-workflow.md` (no paths) — branching strategy, protected branches, commit format
- `naming-conventions.md` — folder, file, component, function naming
- `api-conventions.md` — REST patterns, validation approach, error shapes
- `openapi-sync.md` — "update the spec before committing API changes"
- `package-manager.md` — which package manager to use (scoped to `**/package.json`)

See [examples/rules/](examples/rules/) for templates.

---

### 3. Split large docs into single-topic files

If you have a monolithic `CONVENTIONS.md` or `ARCHITECTURE.md`, split it. Single-topic files:
- Load faster into context (model can pull the relevant one)
- Stay current more easily (smaller blast radius when updating)
- Are easier to link from CLAUDE.md

Good split targets:

```
docs/
├── architecture.md      ← system overview, data flow
├── coding-standards.md  ← patterns, naming, organisation
├── testing.md           ← TDD, test patterns, frameworks
├── glossary.md          ← domain terminology
└── engineering/
    ├── api-conventions.md
    ├── database.md
    ├── debugging.md
    └── deployment.md
```

The split is worth doing even if the content doesn't change — a model loading `api-conventions.md` is more precise than one loading `CONVENTIONS.md` and finding the relevant section.

---

## Phase 2: High-value context artifacts (45 min)

These are the artifacts that fix the most common context failures. Build the ones that match your top failure areas.

### OpenAPI spec (if you have an API)

Link your OpenAPI spec directly from CLAUDE.md. This is one of the highest-ROI context artifacts — it gives agents route contracts, request/response shapes, and validation rules without you explaining them.

```markdown
| [openapi-bundle.yaml](api/openapi/openapi-bundle.yaml) | All API routes, schemas, validation |
```

Add a rule to enforce sync:

```markdown
---
description: OpenAPI spec must be updated and validated whenever API routes or shapes change
paths:
  - "api/src/**"
---

## OpenAPI Spec Sync

When making any API changes (new routes, changed request/response shapes, removed endpoints):

1. Update the OpenAPI spec
2. Run validation — must pass before committing: `npm run openapi:validate`

Never let code and spec drift — agents making API changes will generate incorrect
request shapes if the spec doesn't reflect current reality.
```

Add a pre-commit check that validates and diffs the spec so drift gets caught automatically rather than depending on discipline:

```bash
#!/usr/bin/env bash
# scripts/openapi-precommit.sh
set -euo pipefail

if git diff --cached --name-only | grep -q "api/src/"; then
  echo "API changes detected — validating OpenAPI spec..."
  npm run openapi:validate || { echo "❌ OpenAPI validation failed"; exit 1; }
  echo "✅ OpenAPI spec valid"
fi
```

### Event catalog (if you have event-driven flows)

Agents making changes to event-driven code will silently miss side effects without knowing what emits what and who consumes it. A simple JSON catalog is enough:

```json
// docs/event-catalog.json
{
  "reservation.created": {
    "emitter": "reservations-service",
    "consumers": ["notifications-service", "analytics-service", "availability-service"],
    "payload": { "reservationId": "string", "userId": "string", "startTime": "ISO8601" },
    "notes": "Triggers confirmation email and availability cache invalidation"
  },
  "user.verified": {
    "emitter": "auth-service",
    "consumers": ["user-service"],
    "payload": { "userId": "string", "verifiedAt": "ISO8601" },
    "notes": "Required before user can make a reservation"
  }
}
```

Link it from CLAUDE.md. When an agent touches any event-emitting code, it now knows the downstream consequences.

### Service flow traces (for complex or non-obvious flows)

For flows that are hard to derive from code alone — multi-step async processes, flows that cross multiple services — write a trace doc once rather than having agents reconstruct it every session:

```markdown
# docs/flows/reservation-lifecycle.md

## Create Reservation

Entry: `POST /reservations`
→ `reservations-service/create.js`
  → validates availability (calls `availability-service`)
  → creates DB record
  → emits `reservation.created`
    → `notifications-service` sends confirmation email
    → `availability-service` invalidates cache
→ returns 201 with reservation object

## Edge cases
- Concurrent requests for same slot: handled by DB-level unique constraint, returns 409
- Payment failure: reservation created in `pending` state, expires after 15 min via cron
```

Build these for the two or three flows where AI-generated code most frequently gets the sequence wrong.

### Service/architecture pattern reference

Agents that don't know your architecture patterns will invent their own. A simple reference with "when to use which pattern" prevents duplication:

```json
// docs/ai/architecture-patterns.json
{
  "patterns": {
    "simple-service": {
      "when": "CRUD with no side effects, under ~150 lines",
      "structure": ["route-handler", "service", "model"],
      "example": "user profile — read/update, no events, no external calls"
    },
    "domain-service": {
      "when": "Business logic with side effects, events, or external calls",
      "structure": ["route-handler", "service", "domain-model", "event-emitter"],
      "example": "reservation creation — triggers notifications, updates availability"
    }
  }
}
```

---

## Phase 3: Inline code annotations (20 min)

Inline annotations are short comments that give agents stable semantic hooks — they survive refactors and tell an agent what a piece of code *means*, not just what it does.

Four tags cover most cases:

```typescript
// AI:INVARIANT user must be verified before reservation — do not remove this check
if (!user.verified) throw new ForbiddenError('User not verified');

// AI:SCHEMA reservation shape — keep in sync with openapi/reservations/create.yaml
interface CreateReservationBody { ... }

// AI:TEST validates that concurrent reservation attempts for the same slot return 409
describe('concurrent reservation creation', () => { ... })

// AI:CRUD reservation service — create/read/update/delete section boundaries below
```

Add these when:
- A business rule must not be removed or weakened (`AI:INVARIANT`)
- A data shape is the source of truth for a contract (`AI:SCHEMA`)
- A test validates a specific non-obvious invariant (`AI:TEST`)
- A large service file has CRUD section boundaries (`AI:CRUD`)

Don't annotate obvious code. The value is signal density — too many annotations and the pattern loses meaning.

---

## Phase 4: Automation (15 min)

Manual context maintenance doesn't survive contact with a real codebase. Automate the sync loop so humans aren't responsible for keeping context fresh.

```bash
#!/usr/bin/env bash
# scripts/ai-precommit.sh — runs on every commit
set -euo pipefail

# Validate OpenAPI spec if API files changed
if git diff --cached --name-only | grep -q "api/src/"; then
  npm run openapi:validate || exit 1
fi

# Regenerate context snapshot if docs changed
if git diff --cached --name-only | grep -q "docs/"; then
  npm run ai:context 2>/dev/null || true
  git add docs/ai/auto-context.md 2>/dev/null || true
fi

echo "✅ AI context checks passed"
```

Wire it into your pre-commit hook. The goal is: code change → context stays in sync automatically, not via discipline.

---

## Maintenance

Context engineering isn't a setup task. The system degrades without active maintenance.

**What triggers a context update:**
- An AI session produces a pattern that doesn't belong in the codebase → it found a gap in conventions docs
- An agent invents a route that already exists → OpenAPI spec isn't linked or is stale
- A refactor happens and the architecture patterns doc still describes the old approach → doc drift

**Lightweight maintenance loop:**
1. After any AI session that required repeated corrections — note what the correction was and whether a context file could have prevented it
2. Monthly — check that linked docs in CLAUDE.md reflect actual file paths and current content
3. When a significant pattern changes — update the relevant doc before closing the PR (same commit is best)

**Drift signals:**
- CLAUDE.md links to files that no longer exist
- Architecture patterns doc describes a structure the codebase abandoned
- Event catalog missing events you added last quarter
- Agents consistently ask the same clarifying question → the answer belongs in a doc

---

## File structure summary

```
your-repo/
├── CLAUDE.md                        # Short, navigational — map to depth
├── .claude/
│   └── rules/
│       ├── git-workflow.md          # Universal — loads every session
│       ├── naming-conventions.md    # Scoped to source paths
│       ├── api-conventions.md       # Scoped to api/src/**
│       └── openapi-sync.md          # Scoped to api/src/**
├── docs/
│   ├── architecture.md
│   ├── coding-standards.md
│   ├── testing.md
│   ├── glossary.md
│   ├── event-catalog.json           # Event-driven systems
│   ├── flows/
│   │   └── [key-flow].md            # Complex flow traces
│   └── ai/
│       ├── README.md                # Entry point — links to all AI context
│       └── architecture-patterns.json
├── api/
│   └── openapi/
│       └── openapi-bundle.yaml      # Linked from CLAUDE.md
└── scripts/
    ├── ai-precommit.sh
    └── openapi-validate.sh
```

---

## Checklist

- [ ] CLAUDE.md: short overview + linked doc table + 3–5 critical rules
- [ ] `.claude/rules/`: git-workflow, naming-conventions, api-conventions minimum
- [ ] Large docs split into single-topic files, linked from CLAUDE.md
- [ ] OpenAPI spec linked (if applicable) + pre-commit validation
- [ ] Event catalog created (if event-driven)
- [ ] Service pattern reference created
- [ ] Flow traces for top 2–3 complex flows
- [ ] `AI:INVARIANT` on critical business rules
- [ ] `AI:TEST` on non-obvious test intent
- [ ] Pre-commit hook wired up

**Total setup: ~2 hours | Ongoing: ~15 min per sprint**
