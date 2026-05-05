#!/usr/bin/env bash
# openapi-diff.sh
#
# Produces a markdown summary of OpenAPI changes between the current branch
# and a base ref. Useful for PR descriptions and context snapshots.
#
# Usage:
#   bash scripts/openapi-diff.sh [base_ref] [bundle_path] [output_path]
#
# Defaults:
#   base_ref     = origin/main
#   bundle_path  = openapi/openapi-bundle.yaml   [CONFIGURE]
#   output_path  = docs/ai/spec-diff-latest.md   [CONFIGURE]
#
# Requirements:
#   - Your OpenAPI spec must be bundled into a single file first.
#   - If you use a bundler (redocly, swagger-cli, etc.), run it before this script.
#     Example: npx @redocly/cli bundle openapi/openapi.yaml -o openapi/openapi-bundle.yaml

set -euo pipefail

BASE_REF="${1:-origin/main}"
BUNDLE="${2:-openapi/openapi-bundle.yaml}"    # [CONFIGURE]
OUT_MD="${3:-docs/ai/spec-diff-latest.md}"   # [CONFIGURE]

# Ensure output directory exists
mkdir -p "$(dirname "$OUT_MD")"

# Get previous version of bundle from base ref
if git rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1 && \
   git show "${BASE_REF}:${BUNDLE}" >/dev/null 2>&1; then
  git show "${BASE_REF}:${BUNDLE}" > /tmp/spec-prev.yaml
else
  echo "[openapi-diff] No previous spec at $BASE_REF — treating as new."
  printf "" > /tmp/spec-prev.yaml
fi

cp "$BUNDLE" /tmp/spec-cur.yaml

# Generate unified diff (non-zero exit when differences exist — expected)
diff -u /tmp/spec-prev.yaml /tmp/spec-cur.yaml > /tmp/spec-diff.patch || true

# Extract added/removed paths and operationIds
AddedPaths=$(grep -E '^\+[[:space:]]+/' /tmp/spec-diff.patch | grep -v '^\+\+\+' \
  | sed -E 's/^\+//' | awk '{print $1}' | sort -u || true)
RemovedPaths=$(grep -E '^\-[[:space:]]+/' /tmp/spec-diff.patch | grep -v '^---' \
  | sed -E 's/^-//' | awk '{print $1}' | sort -u || true)
AddedOps=$(grep -E '^\+.*operationId:' /tmp/spec-diff.patch \
  | sed -E 's/^\+.*operationId:[[:space:]]*//' | sort -u || true)
RemovedOps=$(grep -E '^\-.*operationId:' /tmp/spec-diff.patch \
  | sed -E 's/^\-.*operationId:[[:space:]]*//' | sort -u || true)

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

{
  echo "# OpenAPI Diff Summary"
  echo ""
  echo "- Generated: $TIMESTAMP"
  echo "- Base ref: $BASE_REF"
  echo "- Bundle: $BUNDLE"
  echo ""
  echo "## Path Changes"
  if [ -n "$AddedPaths" ]; then
    echo "### Added"
    echo "$AddedPaths" | sed 's/^/- /'
  fi
  if [ -n "$RemovedPaths" ]; then
    echo "### Removed"
    echo "$RemovedPaths" | sed 's/^/- /'
  fi
  if [ -z "${AddedPaths}${RemovedPaths}" ]; then
    echo "_No path additions or removals._"
  fi
  echo ""
  echo "## OperationId Changes"
  if [ -n "$AddedOps" ]; then
    echo "### Added"
    echo "$AddedOps" | sed 's/^/- /'
  fi
  if [ -n "$RemovedOps" ]; then
    echo "### Removed"
    echo "$RemovedOps" | sed 's/^/- /'
  fi
  if [ -z "${AddedOps}${RemovedOps}" ]; then
    echo "_No operationId additions or removals._"
  fi
  echo ""
  echo "## Raw Diff"
  echo '```diff'
  cat /tmp/spec-diff.patch
  echo '```'
} > "$OUT_MD"

echo "✅ OpenAPI diff written to $OUT_MD"
