---
description: OpenAPI spec must be updated and validated whenever API routes or shapes change
paths:
  - "api/src/**"
---

## OpenAPI Spec Sync

When making any API changes — new routes, changed request/response shapes, removed endpoints, modified validation:

1. Update the relevant OpenAPI spec file
2. Run validation before committing: `npm run openapi:validate`

The spec is the contract between API and consumers. Letting code and spec drift means agents
working on API changes will generate incorrect request shapes, missing fields, or wrong
status codes — and the errors won't surface until runtime.

If validation fails: fix the spec, don't skip the check.
