# AI Context Index

## Start Here

1. [CLAUDE.md](../../CLAUDE.md) — project overview + critical rules
2. [architecture.md](../architecture.md) — system overview and data flow
3. [coding-standards.md](../coding-standards.md) — patterns and conventions

## By Task

| I'm about to... | Read this first |
|----------------|----------------|
| Add or change an API route | [openapi-bundle.yaml](../../api/openapi/openapi-bundle.yaml) + [api-conventions.md](../engineering/api-conventions.md) |
| Change event-emitting code | [event-catalog.json](../event-catalog.json) |
| Add a new service or domain | [service-patterns.md](../service-patterns.md) + [architecture.md](../architecture.md) |
| Change shared state/store | [coding-standards.md](../coding-standards.md#shared-state) |
| Write or update tests | [testing.md](../testing.md) |
| Debug an issue | [debugging.md](../engineering/debugging.md) |

## Generated Artifacts

- `auto-context.md` — machine-generated snapshot of key source files. **Do not edit.** Large — treat as last-resort fallback, not primary navigation.

## Maintenance

Context files are linked from CLAUDE.md and updated when the code they describe changes. If you notice a doc is stale or missing, open an issue or update it in the same PR as the code change.
