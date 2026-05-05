# AI Context Engineering Best Practices - EXPANDED EDITION
## Technical Implementation Deep Dive
### Based on production monorepo analysis

**Last Updated:** 2026-01-21
**Source Repository:** Production Node.js/React monorepo
**Analysis Agent:** Claude Code exploration of production AI context system

---

## Table of Contents

- [Quick Reference: Value-Ordered Practices](#quick-reference-value-ordered-practices)
- [Section A: Context Window & File Size Management](#section-a-context-window--file-size-management)
- [Section B: File Linking & Cross-Reference Strategies](#section-b-file-linking--cross-reference-strategies)
- [Section C: Bash Script Patterns & Automation](#section-c-bash-script-patterns--automation)
- [Section D: Additional High-Value Learnings](#section-d-additional-high-value-learnings)
- [Section E: Implementation Priority for New Repos](#section-e-implementation-priority-for-new-repos)
- [Section F: Core Best Practices (Original Guide)](#section-f-core-best-practices-original-guide)

---

## Quick Reference: Value-Ordered Practices

### Top 10 Most Valuable Learnings (Ordered by Impact)

1. **Never Preload Large Files (auto-context.md is 4.1MB, use only as last resort)**
   - Saves tokens, increases speed, improves quality
   - Progressive refinement beats one-shot context dumps

2. **Implement File Size Limits in Generation Scripts (120KB, 1200 lines)**
   - Prevents bloat from entering context pipeline
   - Binary detection algorithm (>30% non-printable = binary)

3. **Progressive Refinement Pattern (Broad 12 → Narrow 8 → Verify 5)**
   - Multiple focused queries > one comprehensive query
   - Summarize between steps (don't carry forward full results)

4. **Graceful Degradation Pattern (RAG is optional, bash exit codes)**
   - Check availability before using: `bash scripts/check-rag-available.sh`
   - Always document fallback patterns (Grep/Glob)

5. **Pre-Commit Orchestration (all validations in one script)**
   - Auto-regenerate context on commit
   - Auto-insert missing annotations
   - Fail fast on drift detection (>20% size reduction)

6. **Bidirectional File Linking (docs reference code, code references docs)**
   - Relative paths in markdown: `[rag-guide.md](rag-guide.md)`
   - Line numbers in code: `api/services/foo.ts:145`
   - Semantic anchors: `AI:INVARIANT See architecture-patterns.json`

7. **JSON Indices with Decision Trees (machine-readable > human-readable)**
   - Structured data AI can query algorithmically
   - Include when/why/examples for each pattern

8. **Context Window Discipline Checklist**
   - <10KB: read whole | 10-50KB: chunks | 50-500KB: search first | >500KB: never read
   - Checkpoint every ~10 actions, summarize tool outputs

9. **Test Intent Auto-Tagging (idempotent, audit in pre-commit)**
   - Derive purpose from filename + first describe block
   - Enforce on critical tests (reservation, payment, auth)

10. **Document Expected File Sizes (set budgets, monitor growth)**
    - Root instructions <10KB, guides <20KB, JSON <10KB, generated <5MB
    - Alert if total context >10MB (needs pruning)

---

## SECTION A: CONTEXT WINDOW & FILE SIZE MANAGEMENT

### A1. The Context Window Problem

**Key Insight:** Modern LLMs have 200K+ token windows, but filling them is expensive, slow, and reduces quality.

**Production solution:
- **Never preload large artifacts** - The 4.1MB `auto-context.md` is a *last resort fallback*, not primary context
- **Progressive disclosure** - Read targeted files, not entire codebase
- **Checkpoint every ~10 actions** - Verify intermediate results before continuing
- **Summarize tool outputs** - Don't dump raw JSON; extract insights first

**Specific File Size Limits (from `generate-ai-context.js`):**

```javascript
const defaultConfig = {
  maxBytes: 120_000,        // ~120KB per file (prevents large files in snapshot)
  maxLines: 1200,           // Max 1200 lines per file
  // Files exceeding these limits are skipped with reason: 'too_large' or 'too_many_lines'
};
```

**Real File Sizes (docs/ai/):**
```
4.1M  auto-context.md           ← GENERATED, never hand-edit, last-resort only
16K   rag-invocation-patterns.md ← Human-readable reference guide
8.8K  ai-enrichment-todo.md     ← Planning doc
7.8K  ATLASSIAN-MCP-USAGE.md    ← Integration guide
6.6K  component-library-index.json ← Machine-readable index
5.7K  ai-documentation-structure.md ← Meta-documentation
```

**Critical Practice:**
- Files under 10KB are **readable in single pass**
- Files 10-50KB should be **read in chunks** (use offset/limit)
- Files 50KB+ should be **searched first** (Grep), then read targeted sections
- Files 500KB+ should **never be read whole** - always use RAG or search

---

### A2. Progressive Refinement Pattern (Context Efficiency)

**From `rag-invocation-patterns.md`:**

**Anti-Pattern (Wastes Context):**
```bash
# ❌ One-shot large query - 20 results = too much context
python tools/rag/rag_cli.py query \
  --q "reservation renewal validation payment error handling tests" \
  --top-k 20 --format json
```

**Best Practice (Progressive Refinement):**
```bash
# ✅ Step 1: Broad discovery (12 results max)
python tools/rag/rag_cli.py query \
  --corpus all \
  --q "reservation renewal" \
  --top-k 12 --format json

# Analyze: Most implementation in api/renewals

# ✅ Step 2: Narrow to specific area (8 results max)
python tools/rag/rag_cli.py query \
  --corpus code \
  --q "renewal validation logic" \
  --filter-area api \
  --top-k 8 --format json

# Analyze: Validation in service + Joi schemas

# ✅ Step 3: Get specific details with context (5 results max)
python tools/rag/rag_cli.py query \
  --corpus code \
  --q "renewal payment validation schema" \
  --filter-area api \
  --enrich \
  --top-k 5 --format json
```

**Benefits:**
- Step 1: 12 chunks (broad understanding)
- Step 2: 8 chunks (focused area)
- Step 3: 5 chunks (specific implementation)
- **Total: 25 focused results across 3 queries** vs. **20 unfocused results in 1 query**
- Higher signal-to-noise ratio
- Lower token cost (summarize between steps)

**Token Efficiency Rules:**
1. **top-k 5-8** for focused queries
2. **top-k 12** for discovery queries only
3. **top-k 20+** is always wrong
4. **Summarize between queries** - don't carry forward full JSON

---

### A3. File Skipping Strategy (from generate-ai-context.js)

**Allowlist-First Approach:**
```javascript
allow: [
  'api/src/application/**/*.js',
  'docs/engineering/**/*.md',
  'scripts/*.js',
  'shared/**/*.{js,jsx,ts,tsx}',
  // Only matching patterns included
],
deny: [
  '**/node_modules/**',
  '**/dist/**', '**/build/**',
  '**/*.min.js', '**/*.map',
  '**/*.png', '**/*.jpg', '**/*.pdf',
  '**/coverage/**',
  '**/*.lock'  // package-lock.json, yarn.lock
]
```

**Binary Detection Algorithm:**
```javascript
function isBinary(buf) {
  const slice = buf.slice(0, 8000);
  let control = 0;
  for (const b of slice) {
    if (b === 9 || b === 10 || b === 13) continue; // tab, newline, carriage return
    if (b < 32 || b === 127) control++;
  }
  return control / slice.length > 0.3; // If >30% non-printable, treat as binary
}
```

**Skipping Reasons Tracked:**
```javascript
{ file: 'path/to/file.js', reason: 'too_large' }       // > maxBytes
{ file: 'path/to/file.js', reason: 'too_many_lines' }  // > maxLines
{ file: 'path/to/file.js', reason: 'binary' }          // Binary file
{ file: 'path/to/file.js', reason: 'strip_list' }      // Explicitly excluded
```

**Output Summary:**
```markdown
Skipped files summary:
- too_large: 12
- too_many_lines: 8
- binary: 45
- strip_list: 3
```

---

## SECTION B: FILE LINKING & CROSS-REFERENCE STRATEGIES

### B1. Documentation Hierarchy with Explicit Links

**From `ai-documentation-structure.md`:**

```
1. User request / acceptance criteria (highest priority)
   ↓
2. Root AGENTS.md (behavioral protocols)
   → References: .copilot-instructions, docs/ai/rag-guide.md
   ↓
3. .copilot-instructions (coding conventions)
   → References: docs/engineering/CONVENTIONS.md
   ↓
4. docs/ai/ generated artifacts
   → References: Inline AI: anchors in code
   ↓
5. Legacy docs (avoid unless explicitly requested)
```

**Link Format Standards:**

**Markdown Links (Relative Paths):**
```markdown
[docs/ai/README.md](docs/ai/README.md)  # Relative from repo root
[rag-guide.md](rag-guide.md)            # Relative from current dir
```

**Inline Code References (Line Numbers):**
```typescript
// Defined in src/services/renewal-service.ts:145
// See validation logic at api/routes/renewals.js:67-82
// AI:INVARIANT Referenced by shared/store/reservationsSlice.ts:234
```

**CLI Tool References (with context):**
```bash
# Check availability first: bash scripts/check-rag-available.sh
# See AGENTS.md for decision tree
# Field definitions in docs/ai/rag-guide.md
```

---

### B2. Cross-Artifact Linking Patterns

**Entry Point Pattern (docs/ai/README.md):**
```markdown
# AI Context Index

## Getting Started
1. Read this file first (you are here)
2. Behavioral protocols → [../AGENTS.md](../AGENTS.md)
3. RAG usage → [rag-guide.md](rag-guide.md)
4. Advanced patterns → [rag-invocation-patterns.md](rag-invocation-patterns.md)

## Quick Links by Task
- **Exploring codebase?** → Use RAG (see [rag-guide.md](rag-guide.md))
- **Planning feature?** → Check architecture patterns ([architecture-patterns.json](architecture-patterns.json))
- **Writing tests?** → See test patterns ([docs/engineering/TESTING.md](../engineering/TESTING.md))
```

**JSON Index with File References:**
```json
{
  "servicePattern": {
    "when": "95% of codebase, simple CRUD",
    "structure": "3 files (routes, service, model)",
    "examples": [
      {
        "feature": "renewals",
        "files": {
          "routes": "api/src/application/renewals/renewals-routes.js:1-150",
          "service": "api/src/application/renewals/renewals-service.js:1-320",
          "model": "api/src/models/ReservationRenewal.js:1-85"
        }
      }
    ]
  }
}
```

---

### B3. Semantic Anchoring for Code-to-Doc Links

**Inline Anchor Pattern:**
```typescript
// AI:INVARIANT Renewals must not overlap with existing reservations
// See docs/ai/architecture-patterns.json → servicePattern → validation
async function validateRenewalWindow(renewal: Renewal) {
  // implementation
}

// AI:TEST Purpose: validates renewal non-overlap invariant
// References: api/services/renewal-service.ts:145 (validateRenewalWindow)
describe('Renewal validation', () => {
  test('rejects overlapping renewals', async () => {
    // test
  });
});
```

**Benefits:**
- **Bidirectional linking** - docs reference code, code references docs
- **Stable across refactors** - semantic meaning preserved even if line numbers change
- **AI-parseable** - can be extracted into index automatically

---

## SECTION C: BASH SCRIPT PATTERNS & AUTOMATION

### C1. Graceful Degradation Pattern (RAG Availability)

**From `scripts/check-rag-available.sh`:**

```bash
#!/usr/bin/env bash
set -e

# Check if Python is available
if ! command -v python &> /dev/null; then
    echo "RAG_AVAILABLE=false"
    echo "REASON=python_not_found"
    exit 1
fi

# Check if RAG CLI exists
if [ ! -f "tools/rag/rag_cli.py" ]; then
    echo "RAG_AVAILABLE=false"
    echo "REASON=rag_cli_not_found"
    exit 1
fi

# Try a minimal query to check dependencies and index
if python tools/rag/rag_cli.py query --q "test" --top-k 1 --format json &> /dev/null; then
    echo "RAG_AVAILABLE=true"
    exit 0
else
    echo "RAG_AVAILABLE=false"
    echo "REASON=dependencies_or_index_missing"
    echo "HINT=Run 'npm run rag:setup' and 'npm run rag:index' to set up RAG"
    exit 1
fi
```

**Usage Pattern (in AI agents):**
```bash
# Check before using RAG
if bash scripts/check-rag-available.sh; then
  # Use RAG
  python tools/rag/rag_cli.py query --q "search" --top-k 5
else
  # Fallback to grep/glob
  grep -rn "search" api/ shared/ | head -20
fi
```

**Key Principles:**
- **Exit codes** - 0 = success, 1 = failure (standard bash convention)
- **Structured output** - KEY=value format for parsing
- **Helpful hints** - Suggest remediation commands
- **Silent on success** - Only output on failure (for scripting)

---

### C2. Pre-Commit Orchestration Pattern

**From `scripts/ai-precommit.sh`:**

```bash
#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

echo "== AI Context Pre-Commit Checks =="

# 1. Regenerate context
echo "Regenerating AI context..."
npm run ai:context || {
  echo "❌ Context generation failed"
  exit 1
}

# 2. Validate environment sync
echo "Checking environment sync..."
npm run env:check || {
  echo "❌ Environment validation failed"
  exit 1
}

# 3. Auto-stage updated context if changed
if git diff --quiet docs/ai/auto-context.md; then
  echo "✓ No context changes"
else
  echo "Staging updated auto-context.md"
  git add docs/ai/auto-context.md
fi

# 4. Insert missing test tags
echo "Checking test tags..."
npm run ai:tests:tag

# 5. Audit test intent coverage
npm run ai:tests:audit || {
  echo "❌ Test audit failed - add AI:TEST headers"
  exit 1
}

echo "✅ All pre-commit checks passed"
```

**Git Hook Integration (package.json):**
```json
{
  "scripts": {
    "ai:precommit": "bash scripts/ai-precommit.sh",
    "prepare": "husky install",
  },
  "lint-staged": {
    "*.{js,ts,jsx,tsx}": ["eslint --fix", "prettier --write"],
    "*.md": ["prettier --write"]
  }
}
```

**.husky/pre-commit:**
```bash
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

npm run ai:precommit
npx lint-staged
```

---

### C3. Onboarding Script Pattern

**From `scripts/ai-onboard.sh`:**

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "== AI Context Onboarding =="
echo ""
echo "📚 Claude Code Setup & Documentation:"
echo "   .claude/README.md           - Complete Claude Code setup guide"
echo "   .claude/QUICK-START.md      - Quick start guide (5 minutes)"
echo ""
echo "📖 Engineering Docs:"
echo "   docs/engineering/onboarding/README.md - General onboarding"
echo "   docs/engineering/ai-context-overview.md - AI context overview"
echo ""
echo "🔧 After editing AI docs: npm run ai:context"
echo ""
echo "🔌 MCP servers setup:"
echo "   - Repo config: .mcp/servers.json"
echo "   - To enable for CLI/agents, add to your shell profile (e.g., ~/.zshrc):"
echo "     export MCP_SERVERS_CONFIG=.mcp/servers.json"

if command -v direnv >/dev/null 2>&1; then
  echo "   - direnv detected: create ./.envrc with the line above, then: direnv allow"
else
  echo "   - (Optional) Install direnv for per-repo env loading: https://direnv.net"
fi
```

**Progressive Disclosure Pattern:**
1. **Essential first** - Most important docs at top
2. **Grouped by purpose** - Setup, engineering, tooling
3. **Next actions clear** - "After editing AI docs: npm run ai:context"
4. **Conditional advice** - Check if direnv installed before suggesting it

---

### C4. Error Handling & Recovery Patterns

**Detect Drift with Size Checks:**
```bash
# Before regeneration
OLD_SIZE=$(wc -l < docs/ai/auto-context.md)

# Regenerate
npm run ai:context

# After regeneration
NEW_SIZE=$(wc -l < docs/ai/auto-context.md)

# Check for unexpected large deletions (>20% reduction)
DIFF=$((OLD_SIZE - NEW_SIZE))
PCT=$((DIFF * 100 / OLD_SIZE))

if [ $PCT -gt 20 ]; then
  echo "❌ WARNING: Context reduced by ${PCT}% (${DIFF} lines)"
  echo "This may indicate missing source files or broken generation"
  exit 1
fi
```

**Retry with Exponential Backoff:**
```bash
attempt=0
max_attempts=3
delay=2

while [ $attempt -lt $max_attempts ]; do
  if npm run ai:context; then
    echo "✅ Context generated successfully"
    break
  fi

  attempt=$((attempt + 1))
  if [ $attempt -lt $max_attempts ]; then
    echo "⚠️  Attempt $attempt failed, retrying in ${delay}s..."
    sleep $delay
    delay=$((delay * 2))
  else
    echo "❌ Failed after $max_attempts attempts"
    exit 1
  fi
done
```

---

## SECTION D: ADDITIONAL HIGH-VALUE LEARNINGS

### D1. Auto-Context Generation Snapshot Strategy

**Key Insight:** The 4.1MB `auto-context.md` is **generated, not curated**

**Structure:**
```markdown
---
path: api/src/application/renewals/renewals-service.js
lines: 320
hash: a3f2b1c9d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9
---
[File contents here]

---
path: shared/store/reservationsSlice.ts
lines: 456
hash: b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3
---
[File contents here]
```

**Hash Usage:**
- Detects if file changed since last generation
- Enables incremental updates (only regenerate changed files)
- Prevents unnecessary regeneration

**When to Use:**
- ✅ **Last resort** when targeted search fails
- ✅ **Discovery phase** to understand codebase structure
- ❌ **Never as primary context** - too large, unfocused
- ❌ **Never hand-edit** - always regenerate

---

### D2. JSON Index Design Patterns

**Machine-Readable > Human-Readable for AI:**

**Good (Structured, Queryable):**
```json
{
  "patterns": {
    "servicePattern": {
      "when": "95% of codebase, simple CRUD, <200 lines",
      "files": 3,
      "structure": ["routes", "service", "model"],
      "examples": [
        {"feature": "renewals", "loc": 903, "complexity": "low"}
      ]
    }
  }
}
```

**Better (With Decision Tree):**
```json
{
  "decisionTree": {
    "hasComplexBusinessLogic": {
      "yes": {
        "multipleWorkflows": {
          "yes": "Use DDD pattern",
          "no": "Check service size"
        }
      },
      "no": "Use service pattern"
    }
  }
}
```

**Benefits:**
- AI can traverse decision tree algorithmically
- No natural language ambiguity
- Easy to extend with new patterns

---

### D3. Test Intent Tag Automation

**Auto-Insert Strategy (idempotent):**

```javascript
// scripts/ai-insert-test-tags.js (simplified)
function deriveTestPurpose(filePath, content) {
  const filename = path.basename(filePath, '.test.ts');
  const firstDescribe = content.match(/describe\(['"](.+?)['"]/)?.[1];

  // Derive purpose from filename + first describe
  return `validates ${filename} ${firstDescribe || 'behavior'}`;
}

function insertTestTag(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');

  // Already has tag? Skip
  if (content.includes('// AI:TEST')) return;

  const purpose = deriveTestPurpose(filePath, content);
  const tag = `// AI:TEST Purpose: ${purpose}\n`;

  fs.writeFileSync(filePath, tag + content);
}
```

**Audit Strategy:**
```javascript
// scripts/ai-audit-tests.js (simplified)
const CRITICAL_PATTERNS = [
  '**/reservation*.test.ts',
  '**/agreement*.test.ts',
  '**/payment*.test.ts'
];

function auditTests() {
  const files = glob.sync(CRITICAL_PATTERNS);
  const missing = [];

  for (const file of files) {
    const content = fs.readFileSync(file, 'utf8');
    if (!content.includes('// AI:TEST')) {
      missing.push(file);
    }
  }

  if (missing.length > 0) {
    console.error('Missing AI:TEST headers:', missing);
    process.exit(1);
  }
}
```

---

### D4. Context Window Discipline Checklist

**From `AGENTS.md`:**

**DO:**
- ✅ Prefer targeted reads (`Grep`, `Read` with ranges)
- ✅ Summarize RAG results before proceeding
- ✅ Checkpoint every ~10 actions
- ✅ Use progressive refinement (broad → narrow → verify)
- ✅ Read small files whole, large files in chunks
- ✅ Consult auto-context.md only as last resort

**DON'T:**
- ❌ Preload large artifacts speculatively
- ❌ Read entire 4MB auto-context.md file
- ❌ Dump raw 20+ result JSON without summarizing
- ❌ Read files >50KB without searching first
- ❌ Skip intermediate verification steps

**Quantitative Guidance:**
- Files <10KB: Read whole ✅
- Files 10-50KB: Read in chunks (use offset/limit) ✅
- Files 50-500KB: Search first (Grep), then read targeted sections ✅
- Files >500KB: Never read whole - use RAG or fail ❌

---

### D5. Local RAG as Optional Enhancement

**Key Architectural Decision:**
```
RAG is OPTIONAL - system must work without it
  ↓
Graceful degradation to Grep/Glob/Read
  ↓
Check availability before using (check-rag-available.sh)
  ↓
Document fallback patterns (rag-invocation-patterns.md)
```

**Benefits of This Approach:**
1. **No hard dependency** - onboarding works without Python setup
2. **Progressive enhancement** - can add RAG later for power users
3. **Resilient** - system doesn't break if RAG index gets corrupted
4. **Portable** - repo works on any machine, even without tooling

**When to Use RAG vs Grep:**

| Task | Tool | Reason |
|------|------|--------|
| Find exact string | Grep | Exact match, no semantic needed |
| Find file by name | Glob | Name-based, no content needed |
| Find similar patterns | RAG | Semantic similarity |
| Understand feature | RAG | Multi-file comprehension |
| Find all usages | Grep | Exact symbol matching |
| Impact analysis | RAG | Dependency graph traversal |

---

## SECTION E: IMPLEMENTATION PRIORITY FOR NEW REPOS

### E1. Minimum Viable Context System

**Week 1 (Foundation):**
1. Create `AGENTS.md` with behavioral protocols
2. Create `.copilot-instructions` with coding conventions
3. Add file size limits to any generation scripts (120KB, 1200 lines)
4. Document "never preload large files" principle

**Week 2 (Automation):**
5. Build simple `generate-ai-context.js` with allowlist/deny patterns
6. Add binary detection logic
7. Create pre-commit hook orchestrator
8. Add graceful degradation checks (bash exit codes)

**Week 3 (Structured Knowledge):**
9. Create 3-5 JSON indices (conventions, patterns, etc.)
10. Modularize OpenAPI or schema documentation
11. Document progressive refinement patterns
12. Add linking between docs (relative paths)

### E2. File Size Budget Planning

**Recommended Budgets:**

| File Type | Individual | Total Corpus |
|-----------|------------|--------------|
| Root instructions (AGENTS.md, CLAUDE.md) | <10KB | <30KB |
| Human-readable guides (rag-guide.md) | <20KB | <100KB |
| JSON indices (patterns, conventions) | <10KB | <50KB |
| Generated snapshot (auto-context.md) | <5MB | <5MB |
| **TOTAL AI CONTEXT** | - | **<5.2MB** |

**Production example:
```
AGENTS.md                      ~3KB
docs/ai/human-readable guides   ~50KB
docs/ai/JSON indices           ~30KB
docs/ai/auto-context.md        4.1MB
------------------------------------------
TOTAL                          ~4.2MB
```

**Critical Thresholds:**
- Single file >100KB: Consider splitting or generating
- Total context >10MB: Too large, needs aggressive pruning
- Any file >1MB: Must be generated, never hand-maintained

---

### E3. Linking Strategy Template

**Entry Point (README.md):**
```markdown
# Project AI Context

## Start Here
1. [AGENTS.md](../AGENTS.md) - How AI agents should behave
2. [.copilot-instructions](../.copilot-instructions) - Coding patterns

## By Task
- **Feature planning?** → [architecture-patterns.json](architecture-patterns.json)
- **Writing tests?** → [docs/engineering/TESTING.md](../engineering/TESTING.md)
- **API changes?** → [api-conventions.json](api-conventions.json)

## Tools
- **RAG available?** → `bash scripts/check-rag-available.sh`
- **Search patterns** → [rag-invocation-patterns.md](rag-invocation-patterns.md)
```

**Inline Code Links:**
```typescript
// AI:INVARIANT Defined in api-conventions.json → validation → required_fields
// AI:TEST References: api/services/foo.ts:145 (validateFoo function)
// See architecture-patterns.json → servicePattern for structure
```

---

## SECTION F: CORE BEST PRACTICES (ORIGINAL GUIDE)

### Tier 1: Foundation (Highest ROI)

1. **Establish Documentation Hierarchy**
   - Create root `AGENTS.md` with behavioral protocols (how AI should think/act)
   - Create root `.copilot-instructions` with coding conventions (what patterns to use)
   - Create root `CLAUDE.md` or `README.md` with dev commands and project overview
   - Define explicit precedence: User request → AGENTS.md → .copilot-instructions → docs
   - Use package-specific overrides where needed (e.g., `api/.copilot-instructions`)

2. **Implement Semantic Anchoring System**
   - Add inline `// AI:<TAG>` comments at critical code locations
   - Core tags: `AI:INVARIANT` (business rules), `AI:TEST` (test intent), `AI:SCHEMA` (model definitions)
   - Enforce anchors stay synchronized with code refactors
   - High signal-to-noise ratio: only anchor truly critical logic

3. **Automate Context Generation Pipeline**
   - Build master orchestrator script (e.g., `generate-ai-context.js`)
   - Auto-generate artifacts from source of truth (OpenAPI, schemas, models)
   - **Never hand-edit generated artifacts** — always regenerate
   - Run via `npm run ai:context` and pre-commit hooks

4. **Add Pre-Commit Guardrails**
   - Create `ai-precommit.sh` hook orchestrating all validations
   - Auto-regenerate context on commit
   - Auto-insert missing annotations (test headers, anchors)
   - Audit for drift/staleness
   - Fail CI on significant unexpected deletions

### Tier 2: Structured Knowledge (High ROI)

5. **Modularize OpenAPI Specifications**
   - Split into domain-specific files (`auth.yaml`, `users.yaml`, `reservations.yaml`)
   - Keep shared components in `_common.yaml`
   - Auto-bundle into single dereferenced spec
   - Auto-generate missing operationIds from `{verb}{Path}`
   - Auto-enrich with examples for common shapes

6. **Create Machine-Readable Indices**
   - Export JSON artifacts: `api-conventions.json`, `architecture-patterns.json`, `component-library-index.json`
   - Include decision trees (e.g., Service Pattern vs DDD Pattern)
   - Document naming conventions, tag invalidation rules, environment variables
   - Makes patterns queryable by AI without natural language parsing

7. **Implement Test Intent Tagging**
   - Enforce `// AI:TEST Purpose: <short description>` headers on critical test files
   - Auto-insert via script with idempotent logic
   - Audit in pre-commit hook (fail if missing on important tests)
   - Derives purpose from filename + first describe block

8. **Document Token Discipline Principles**
   - Prefer targeted reads over preloading large artifacts
   - Don't load comprehensive context docs proactively (use as last resort)
   - Checkpoint every ~10 actions; verify intermediate results
   - Summarize RAG results instead of dumping verbatim JSON
   - Minimal diffs: smallest patch satisfying request

### Tier 3: Advanced Capabilities (Medium-High ROI)

9. **Integrate Local RAG (Optional but Powerful)**
   - Index code, docs, tickets, schemas into vector database
   - Define semantic fields: `area`, `kind`, `chunk_type`, `recency_boost`, `coverage_pct`
   - Create `rag-guide.md` documenting field definitions and standard flows
   - Document progressive refinement patterns: multiple focused queries > one comprehensive query
   - Make gracefully degradable (fallback to grep/read if unavailable)

10. **Extract Domain Glossary Automatically**
    - Parse OpenAPI schemas, models, and JSDoc for terminology
    - Generate `domain-glossary-candidates.md`
    - Review and curate into canonical glossary
    - Prevents terminology drift and ambiguity

11. **Create Context Usage Documentation**
    - Write `docs/ai/README.md` as entry point
    - Document `rag-invocation-patterns.md` with query templates
    - Explain `ai-documentation-structure.md` (relationship between AGENTS.md and .copilot-instructions)
    - Include anti-patterns and common mistakes

12. **Implement Progressive Query Patterns**
    - Template A: "Explain this feature" (8 focused results)
    - Template B: "Plan a change" (12 results with filters)
    - Template C: "Generate tests" (5 enriched results)
    - Anti-pattern: One-shot large query (20+ results = too much context)

### Tier 4: Refinements (Medium ROI)

13. **Auto-Generate Seed/Invariant Context**
    - Extract invariant info from seed data (fixed IDs, enum values)
    - Document in `docs/ai/seed-context.md`
    - Helps AI understand database constants without querying

14. **Create Architecture Decision Trees**
    - Document when to use Pattern A vs Pattern B
    - Include file counts, complexity thresholds, testability trade-offs
    - Examples: Service Pattern (95% of code, <200 lines) vs DDD Pattern (5%, >200 lines, complex workflows)

15. **Environment Schema Validation**
    - Define `env/variables.schema.json` with all config keys
    - Auto-generate `ENV_VARS.md` documentation
    - Validate `.env` files against schema in pre-commit
    - Export to JSON index for AI queries

16. **Error Code Catalog**
    - Extract error codes and messages from source code
    - Compile into `error-codes.json` or similar
    - Helps AI understand error handling patterns

17. **Expand Annotation Taxonomy (Planned)**
    - Add frontend-specific tags: `AI:SCREEN`, `AI:COMPONENT`, `AI:HOOK`, `AI:FLOW`
    - Add observability tags: `AI:ANALYTICS`, `AI:PERF`
    - Add story tags: `AI:STORY` (Storybook entry points)
    - Create auto-insert/audit scripts for each

### Tier 5: Maintenance & Governance (Important for Scale)

18. **Track Improvement Backlog**
    - Create `docs/ai/ai-enrichment-todo.md`
    - Prioritize by effort vs ROI
    - High-ROI planned: API endpoint catalog, event-to-handler flow map, stale anchor detection

19. **Implement Stale Anchor Detection**
    - Scan for anchors referencing removed identifiers
    - Fail CI on stale annotations
    - Low effort, high ROI for maintenance

20. **Compute Annotation Coverage Metrics**
    - Track (# anchor lines / total lines in target areas)
    - Visualize weak documentation areas
    - Set coverage goals for critical paths

21. **Add IDE Extension Validation**
    - Maintain `.vscode/extensions.json` and `ide/extensions.txt`
    - Validate sync in pre-commit hook
    - Ensures team has consistent AI-assisted tooling

### Tier 6: Workflow Integration (Context-Dependent)

22. **Setup Code Review Automation**
    - Create `ai-code-review.js` using AI CLI tools
    - Run manually or in CI
    - Flag common issues (missing tests, stale anchors, convention violations)

23. **Create Onboarding Script**
    - Build `ai-onboard.sh` that:
      - Validates environment
      - Runs context generation
      - Checks RAG availability
      - Verifies IDE extensions
      - Prints first steps

24. **Document Flow Diagrams**
    - Create `docs/engineering/` flows for complex features
    - Include lifecycle diagrams, state transitions
    - Reference via `AI:LIFECYCLE` anchors in code

---

## Quick Start Priority for New Repos

**Week 1:** Items 1-4 (foundation + guardrails)
**Week 2:** Items 5-7 (structured knowledge)
**Week 3:** Items 8-11 (advanced capabilities + documentation)
**Ongoing:** Items 12-24 (refinements + maintenance)

---

## Key Principles Underlying Success

- **Documentation is source code** — versioned, tested, regenerated, governed
- **Deterministic over manual** — Auto-generate; never hand-edit artifacts
- **Signal over noise** — Anchor only critical logic; avoid speculative annotations
- **Progressive refinement** — Multiple focused queries beat one comprehensive query
- **Graceful degradation** — Tools like RAG should be optional; system works without them
- **Continuous improvement** — Track backlog of high-ROI enhancements

This approach treats AI context as a **first-class engineering artifact** requiring the same rigor as production code.

---

## Appendix: Scripts Reference

### Core Commands

```bash
# Context regeneration
npm run ai:context                  # Full context rebuild
npm run ai:precommit                # Pre-commit guardrails
npm run api:spec:bundle             # Rebuild OpenAPI spec
npm run openapi:validate            # Validate spec + lint

# OpenAPI automation
npm run api:spec:auto-opids         # Add missing operationIds
npm run api:spec:auto-examples      # Enrich with examples
npm run api:spec:audit              # Audit completeness
npm run api:spec:diff               # Diff against main

# Testing & audit
npm run ai:tests:tag                # Insert test headers
npm run ai:tests:audit              # Audit test headers
npm run ai:terms                    # Extract glossary terms
npm run ai:seed:context             # Refresh seed context

# Code review
npm run ai:code-review              # Run copilot code review
npm run env:check                   # Validate env sync

# RAG commands
npm run rag:setup                   # Install RAG dependencies
npm run rag:index                   # Build/update index
npm run rag:query                   # CLI query interface
npm run rag:stats                   # Show index statistics
```

---

## Appendix: File Size Reference

**Example docs/ai/ Directory:

| File | Size | Purpose | Edit Policy |
|------|------|---------|-------------|
| auto-context.md | 4.1MB | Generated snapshot | Never hand-edit |
| rag-invocation-patterns.md | 16KB | Reference guide | Human-curated |
| ai-enrichment-todo.md | 8.8KB | Planning doc | Human-curated |
| ATLASSIAN-MCP-USAGE.md | 7.8KB | Integration guide | Human-curated |
| component-library-index.json | 6.6KB | Machine index | Generated |
| architecture-patterns.json | 5.2KB | Machine index | Semi-generated |
| ai-documentation-structure.md | 5.7KB | Meta-doc | Human-curated |

---

**This guide captures practical implementation patterns from production AI-assisted engineering workflows.**

**The key insight: treat context as a scarce resource, just like memory or CPU, and engineer for efficiency from day one.**
