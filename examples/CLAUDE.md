# CLAUDE.md

## Project Overview

[Your system name] is a [brief description — e.g. "multi-package Node.js/React application for managing X"]:
- **api/**: [Backend — language, framework, DB]
- **web/**: [Frontend — framework, state management]
- **shared/**: [Shared types, utilities]

## Documentation (read on demand)

| Doc | Contents |
|-----|----------|
| [architecture.md](docs/architecture.md) | System overview, data flow, integration patterns |
| [coding-standards.md](docs/coding-standards.md) | Code organisation, patterns, naming, quality standards |
| [testing.md](docs/testing.md) | TDD requirements, test patterns, frameworks per package |
| [glossary.md](docs/glossary.md) | Domain concepts and business terminology |
| [openapi-bundle.yaml](api/openapi/openapi-bundle.yaml) | All API routes, request/response schemas, validation |
| [event-catalog.json](docs/event-catalog.json) | Events, payloads, emitters, consumers |
| [service-patterns.md](docs/service-patterns.md) | Architecture patterns — when to use each, with examples |
| [database.md](docs/engineering/database.md) | DB access, schema docs, query patterns |
| [debugging.md](docs/engineering/debugging.md) | Debugging strategies per service |

**All code must follow the standards in these documents.**

## Critical Rules

- **[Most important constraint]** — [what breaks if violated, e.g. "API tests must run in Docker — host tests skip DB integration and give false-green results"]
- **[Second constraint]** — [e.g. "Update OpenAPI spec before committing API route changes: npm run openapi:validate"]
- **[Third constraint]** — [e.g. "Never commit secrets — env vars validated against env/variables.schema.json"]
- **Never commit or push without explicit user instruction.**

## Known Constraints

- **[Technical gotcha 1]** — [specific issue not obvious from code, e.g. "Branch named `feature/123` blocks creation of `feature/123/sub` — use flat names like `feature/123-sub`"]
- **[Technical gotcha 2]** — [e.g. "TypeScript watch builds re-trigger on their own dist/ output — check watchOptions.excludeDirectories first"]
