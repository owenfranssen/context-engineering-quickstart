---
description: REST API conventions — route patterns, validation, error shapes
paths:
  - "api/src/**"
  - "api/test/**"
---

## API Conventions

### Route patterns

```
GET    /resources          # list
GET    /resources/:id      # get one
POST   /resources          # create
PUT    /resources/:id      # replace
PATCH  /resources/:id      # partial update
DELETE /resources/:id      # delete
```

### Validation

All request bodies validated at the route level before reaching the service. Never validate inside services — the service layer assumes valid input.

### Error shapes

All errors follow the same envelope:

```json
{
  "error": "short_code",
  "message": "Human-readable description",
  "details": {}
}
```

HTTP status codes: 400 (validation), 401 (unauthenticated), 403 (unauthorised), 404 (not found), 409 (conflict), 422 (unprocessable), 500 (server error).

### OpenAPI

Every route must have an OpenAPI definition. See `api/openapi/` for existing examples. Run `npm run openapi:validate` before committing API changes.
