#!/usr/bin/env bash
# ai-precommit.sh
#
# Pre-commit hook that keeps AI context in sync with code changes.
# Wire into your pre-commit setup (.husky/pre-commit, lefthook, etc.)
#
# What it does:
#   1. Validates OpenAPI spec if API files changed
#   2. Runs lint/format on staged files (if lint-staged is configured)
#   3. Regenerates AI context snapshot if docs changed
#
# Adapt the sections marked [CONFIGURE] to match your project structure.

set -euo pipefail

STAGED=$(git diff --cached --name-only)

# ─── 1. OpenAPI validation ─────────────────────────────────────────────────
# [CONFIGURE] Adjust the path pattern and validate command for your project.

API_PATTERN="api/src/"          # files that trigger spec validation
OPENAPI_VALIDATE="npm run openapi:validate"  # your validate command

if echo "$STAGED" | grep -q "$API_PATTERN"; then
  echo "[ai-precommit] API changes detected — validating OpenAPI spec..."
  $OPENAPI_VALIDATE || {
    echo "❌ OpenAPI validation failed. Update the spec before committing API changes."
    exit 1
  }
  echo "✅ OpenAPI spec valid"
fi

# ─── 2. Lint and format ────────────────────────────────────────────────────
# [CONFIGURE] Uncomment and adjust if you're not using lint-staged.
#
# LINT_FILES=$(echo "$STAGED" | grep -E '\.(js|jsx|ts|tsx)$' || true)
# if [ -n "$LINT_FILES" ]; then
#   npx eslint --fix $LINT_FILES && git add $LINT_FILES
#   npx prettier --write $LINT_FILES && git add $LINT_FILES
# fi

# ─── 3. Context regeneration ──────────────────────────────────────────────
# [CONFIGURE] Adjust the docs pattern and context command for your project.

DOCS_PATTERN="docs/"             # files that trigger context regen
CONTEXT_CMD="node scripts/generate-ai-context.js"
CONTEXT_OUTPUT="docs/ai/auto-context.md"

if echo "$STAGED" | grep -q "$DOCS_PATTERN"; then
  echo "[ai-precommit] Docs changed — regenerating AI context snapshot..."
  $CONTEXT_CMD 2>/dev/null || {
    echo "[ai-precommit] Context generation failed (non-fatal, continuing)"
  }
  if [ -f "$CONTEXT_OUTPUT" ]; then
    git add "$CONTEXT_OUTPUT"
  fi
fi

# ─── 4. Drift detection (optional) ────────────────────────────────────────
# Fail if context snapshot shrank by more than 20% — signals files went missing.

if [ -f "$CONTEXT_OUTPUT" ] && git show "HEAD:$CONTEXT_OUTPUT" >/dev/null 2>&1; then
  OLD_LINES=$(git show "HEAD:$CONTEXT_OUTPUT" | wc -l | tr -d ' ')
  NEW_LINES=$(wc -l < "$CONTEXT_OUTPUT" | tr -d ' ')
  if [ "$OLD_LINES" -gt 0 ]; then
    REDUCTION=$(( (OLD_LINES - NEW_LINES) * 100 / OLD_LINES ))
    if [ "$REDUCTION" -gt 20 ]; then
      echo "❌ AI context shrank by ${REDUCTION}% — possible missing files. Run with --dry-run to inspect."
      exit 1
    fi
  fi
fi

echo "✅ AI pre-commit checks passed"
