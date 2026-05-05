---
description: Naming conventions for source files and identifiers
paths:
  - "src/**"
  - "api/src/**"
  - "web/src/**"
---

## Naming Conventions

| Thing | Convention | Example |
|-------|-----------|---------|
| Folders | kebab-case | `reservation-flows/` |
| React components | PascalCase | `ReservationCard.tsx` |
| Hooks | camelCase with `use` prefix | `useReservationStatus.ts` |
| Services / utilities | camelCase | `reservationService.ts` |
| Constants | UPPER_SNAKE_CASE | `MAX_RESERVATION_DAYS` |
| DB columns | snake_case | `created_at`, `user_id` |
| API routes | kebab-case | `/reservation-requests` |
| Test files | co-located, `.test.ts` suffix | `reservationService.test.ts` |
