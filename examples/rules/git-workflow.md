---
description: Git branching strategy and commit conventions — applies to all work
---

## Git Workflow

### Branch naming

```
feature/[ticket-id]-short-description    # new features
fix/[ticket-id]-short-description        # bug fixes
chore/short-description                  # tooling, deps, config
```

### Protected branches

- `main` / `master` — never push directly; PR required
- `staging` — never merge feature branches directly; use the QA flow

### Commit format

```
type(scope): short description

feat(api): add reservation endpoint
fix(web): correct date timezone handling
chore(deps): update typescript to 5.4
```

### Never

- Merge the main/staging branch into a feature branch to resolve conflicts — use a disposable copy branch
- Force push to shared branches
- Commit secrets or credentials
