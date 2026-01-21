# AI Context Engineering Quick Start
## Initialize New Repository with Best Practices

**Target:** 2-hour setup for production-ready AI context system

---

## Phase 1: Foundation (30 minutes)

### 1. Create Root Instructions

**AGENTS.md** (behavioral protocols)
```markdown
# AI Agent Protocols

## Context Window Discipline
- Files <10KB: read whole
- Files 10-50KB: read in chunks (offset/limit)
- Files 50-500KB: search first (Grep), then read sections
- Files >500KB: never read whole - search only

## Workflow
1. Exploration: Read relevant files, no code yet
2. Planning: Use "think hard" for complex tasks, "ultrathink" for architectural decisions
3. Implementation: Follow plan, minimal changes only
4. Commit: Conventional format with co-author tag

## Tool Usage
- Prefer Read/Edit/Write over bash cat/sed/echo
- Use Grep for search, not bash grep
- Check out every ~10 actions, summarize outputs
- Never preload large files speculatively

## Code Quality
- No over-engineering: make only requested changes
- No backwards-compatibility hacks for unused code - delete it
- Security: validate at boundaries only (user input, external APIs)
- Tests: clear targets, avoid mocks for internal code
```

**.copilot-instructions** (coding conventions)
```markdown
# Coding Conventions

## Style
- Folders: kebab-case (user-service/)
- Components: PascalCase (UserCard.tsx)
- Functions/variables: camelCase (getUserData)
- Constants: UPPER_SNAKE_CASE (MAX_RETRIES)

## Architecture
[Add your patterns - Service Pattern, DDD, etc.]

## Testing
- Colocate tests: Component.test.tsx
- AI:TEST headers: `// AI:TEST Purpose: validates user auth flow`
- Cover: happy path + edge cases + errors
- No mocking internal code

## Semantic Anchors
- `// AI:INVARIANT` - business rules that must not break
- `// AI:TEST` - test purpose and scope
- `// AI:SCHEMA` - data model definitions
```

**CLAUDE.md** (project-specific commands)
```markdown
# Project Commands

## Development
```bash
npm start              # Start dev server
npm test              # Run tests
npm run build         # Production build
```

## Architecture
- [Describe structure]
- [Key directories]
- [Integration points]

## Environment Setup
- Node version: [specify]
- Required env vars: [list]
```

---

### 2. Configure File Size Limits

**scripts/generate-ai-context.js**
```javascript
const defaultConfig = {
  maxBytes: 120_000,    // 120KB per file
  maxLines: 1200,
  allow: [
    'src/**/*.{js,ts,jsx,tsx}',
    'docs/**/*.md',
    // Add patterns
  ],
  deny: [
    '**/node_modules/**',
    '**/dist/**', '**/build/**',
    '**/*.min.js', '**/*.map',
    '**/coverage/**',
    '**/*.lock'
  ]
};

// Binary detection (>30% non-printable = binary)
function isBinary(buf) {
  const slice = buf.slice(0, 8000);
  let control = 0;
  for (const b of slice) {
    if (b === 9 || b === 10 || b === 13) continue;
    if (b < 32 || b === 127) control++;
  }
  return control / slice.length > 0.3;
}
```

**package.json**
```json
{
  "scripts": {
    "ai:context": "node scripts/generate-ai-context.js"
  }
}
```

---

### 3. Setup Pre-Commit Hooks

**scripts/ai-precommit.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "== AI Pre-Commit Checks =="

# Regenerate context
npm run ai:context || exit 1

# Auto-stage if changed
if ! git diff --quiet docs/ai/auto-context.md; then
  git add docs/ai/auto-context.md
fi

# Drift detection: fail if >20% size reduction
OLD_SIZE=$(git show HEAD:docs/ai/auto-context.md | wc -l)
NEW_SIZE=$(wc -l < docs/ai/auto-context.md)
DIFF=$((OLD_SIZE - NEW_SIZE))
PCT=$((DIFF * 100 / OLD_SIZE))

if [ $PCT -gt 20 ]; then
  echo "❌ Context reduced by ${PCT}% - possible missing files"
  exit 1
fi

echo "✅ Checks passed"
```

**.husky/pre-commit** (if using husky)
```bash
#!/usr/bin/env sh
npm run ai:precommit
```

---

## Phase 2: Structured Knowledge (45 minutes)

### 4. Create JSON Indices

**docs/ai/architecture-patterns.json**
```json
{
  "patterns": {
    "servicePattern": {
      "when": "Simple CRUD, <200 LOC",
      "files": 3,
      "structure": ["routes", "service", "model"],
      "example": "users service: routes.js (50 LOC), service.js (120 LOC), model.js (30 LOC)"
    },
    "complexPattern": {
      "when": "Multiple workflows, >200 LOC",
      "files": "5+",
      "structure": ["aggregate", "commands", "queries", "domain"],
      "example": "payment processing with retries and webhooks"
    }
  },
  "decisionTree": {
    "complexWorkflows": {
      "yes": "Use complexPattern",
      "no": "Check LOC"
    },
    "LOC": {
      "gt200": "Consider complexPattern",
      "lt200": "Use servicePattern"
    }
  }
}
```

**docs/ai/coding-conventions.json**
```json
{
  "naming": {
    "folders": "kebab-case",
    "components": "PascalCase",
    "functions": "camelCase",
    "constants": "UPPER_SNAKE_CASE"
  },
  "fileStructure": {
    "components": "src/components/[domain]/ComponentName.tsx",
    "tests": "colocated as ComponentName.test.tsx",
    "services": "src/services/[domain]/service-name.ts"
  },
  "imports": {
    "order": ["react", "third-party", "internal-components", "utils", "styles"],
    "aliases": {
      "@components": "src/components",
      "@utils": "src/utils"
    }
  }
}
```

---

### 5. Add Directory Index

**docs/ai/README.md**
```markdown
# AI Context Index

## Start Here
1. [AGENTS.md](../../AGENTS.md) - Agent behavior protocols
2. [.copilot-instructions](../../.copilot-instructions) - Coding conventions
3. [CLAUDE.md](../../CLAUDE.md) - Project commands

## By Task
- **Planning feature?** → [architecture-patterns.json](architecture-patterns.json)
- **Coding?** → [coding-conventions.json](coding-conventions.json)
- **Testing?** → [testing-patterns.json](testing-patterns.json)

## File Size Budget
- Root instructions: <10KB each
- JSON indices: <10KB each
- Generated context: <5MB
- **Total target: <5.2MB**

## Update Process
```bash
npm run ai:context    # Regenerate after changes
```
```

---

## Phase 3: Automation (30 minutes)

### 6. Custom Slash Commands

**.claude/commands/add-feature.md**
```markdown
---
name: add-feature
description: Scaffold new feature following project patterns
---

# Add Feature: $ARGUMENTS

## Step 1: Think & Plan
think hard: Design approach for $ARGUMENTS following architecture-patterns.json

## Step 2: Identify Files
List files to create/modify with line count estimates

## Step 3: Implement
Create files following coding-conventions.json

## Step 4: Test
Generate tests with AI:TEST headers

## Step 5: Validate
```bash
npm test
npm run lint
```
```

**.claude/commands/review.md**
```markdown
---
name: review
description: Review staged changes for quality
---

# Review Staged Changes

Check:
- [ ] Follows architecture patterns
- [ ] Conventions per coding-conventions.json
- [ ] Tests cover happy path + errors
- [ ] AI:INVARIANT on critical logic
- [ ] No hardcoded secrets

Output findings as list or "No issues found"
```

---

### 7. Optional: Graceful RAG

**scripts/check-rag-available.sh**
```bash
#!/usr/bin/env bash
if command -v python &>/dev/null && [ -f "tools/rag/rag_cli.py" ]; then
  python tools/rag/rag_cli.py query --q "test" --top-k 1 &>/dev/null && exit 0
fi
exit 1
```

**Usage in AGENTS.md:**
```markdown
## Search Strategy
```bash
if bash scripts/check-rag-available.sh; then
  # Progressive refinement: Broad (k=12) → Narrow (k=8) → Specific (k=5)
  python tools/rag/rag_cli.py query --q "feature" --top-k 12
else
  # Fallback to grep
  grep -rn "pattern" src/
fi
```
```

---

## Phase 4: Visual Workflows (15 minutes)

### 8. Screenshot Integration

**tmp/** (gitignored)
```
tmp/
├── screenshots/           # Implementation captures
│   ├── feature-v1.png
│   └── feature-v2.png
└── ai-results/           # Headless mode outputs
```

**.gitignore**
```
tmp/
```

**Workflow in AGENTS.md:**
```markdown
## Visual Development
1. Capture: `npm run screenshot` or manual (Cmd+Shift+4)
2. Compare to design mock
3. Prompt: "Compare tmp/screenshots/login-v1.png to designs/login-final.png. Fix spacing (16px not 12px)"
4. Iterate 2-3 times max
```

---

## Phase 5: Metrics (Optional, 15 minutes)

### 9. Track Context Effectiveness

**.claude/metrics-log.md**
```markdown
# Context Effectiveness Log

## 2026-01-21 - Feature: User Auth
- Complexity: Standard
- Thinking mode: think hard
- First attempt success: Yes
- Iterations: 2
- Context docs used: AGENTS.md, architecture-patterns.json
- Time: 25 min
```

**Quarterly review:**
```bash
# Check metrics
- First attempt success rate target: >70%
- Average iterations target: <2.5
- Docs with <40% hit rate: remove or consolidate
```

---

## File Structure Summary

```
my-repo/
├── AGENTS.md                    # Behavioral protocols
├── .copilot-instructions        # Coding conventions
├── CLAUDE.md                    # Project commands
├── .claude/
│   ├── commands/
│   │   ├── add-feature.md
│   │   └── review.md
│   └── metrics-log.md
├── docs/
│   └── ai/
│       ├── README.md
│       ├── architecture-patterns.json
│       ├── coding-conventions.json
│       └── auto-context.md      # Generated
├── scripts/
│   ├── generate-ai-context.js
│   ├── ai-precommit.sh
│   └── check-rag-available.sh
└── tmp/                         # Gitignored
    └── screenshots/
```

---

## Quick Start Checklist

- [ ] Create AGENTS.md, .copilot-instructions, CLAUDE.md
- [ ] Add generate-ai-context.js with file size limits
- [ ] Setup ai-precommit.sh with drift detection
- [ ] Create 2-3 JSON indices (patterns, conventions)
- [ ] Add docs/ai/README.md as entry point
- [ ] Create 2 custom slash commands
- [ ] Setup tmp/ directory and .gitignore
- [ ] Run `npm run ai:context` to verify
- [ ] Test pre-commit hook
- [ ] Document in project README

---

## Maintenance

### Weekly
- Review metrics-log.md for patterns

### Monthly
- Check file size budgets (Section 5)
- Update patterns based on actual usage

### Quarterly
- Audit context hit rate (which docs actually used?)
- Remove low-value docs (<40% hit rate)
- Refine high-value docs for conciseness

---

**Total setup: ~2 hours | ROI: 30-45 min savings per complex task**
