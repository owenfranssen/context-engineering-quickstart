# Context Engineering for AI-Assisted Development

The first sign something was wrong with my AI-assisted workflow wasn't a dramatic failure. It was inconsistency.

The same question, different answers. Confident references to patterns that didn't exist in the codebase, or misses of ones that did. Every session starting with the same re-explanation — *don't change files outside this task, follow our existing patterns, explain your plan before you start* — just to get back to where the last session ended.

This repository documents what actually works, based on production use in a brownfield monorepo. Not a theoretical framework — patterns extracted from real context failures and what fixed them.

→ [Quick start](quickstart.md) — get a working context system in ~2 hours  
→ [Deep dive](deep-dive.md) — the full pattern library with implementation detail  
→ [Examples](examples/) — sanitised, copy-pasteable file templates

---

## What context engineering actually is

It's not documentation. Documentation describes how the system works for humans. Context engineering shapes what the AI knows, when it knows it, and how confidently it can act without asking.

The difference matters because most context failures aren't caused by the model being wrong — they're caused by the model not having enough signal to be right. It fills gaps with plausible-sounding guesses. In a complex codebase, those guesses compound.

**What didn't work:**
- Dumping everything into every prompt — didn't scale, couldn't be shared
- Documenting everything — the library grew and went stale; nobody read it, human or AI

**What works:**
- Identifying which specific areas generate the most AI context failures, and targeting those first
- Linking explicitly from your instruction files rather than hoping the model finds things
- Keeping instruction files short and navigational — pointers to depth, not depth itself
- Splitting large docs into single-topic files, linked by name
- Automating the sync between code and context so humans aren't responsible for keeping it fresh

---

## The progression

```
Context setup                         Implementation
─────────────────────────────────     ────────────────────────────
CLAUDE.md (short, navigational)  →    write-plan (uses project_context)
  └─ links to focused docs        →    flow (parallel agents, verified merge)
       └─ OpenAPI spec                  └─ every agent gets your conventions
       └─ event catalog
       └─ service contracts
       └─ .claude/rules/
```

Once your context is set up, [ai-engineering-plugin](https://github.com/owenfranssen/ai-engineering-plugin) skills — particularly `flow` and `write-plan` — capture your CLAUDE.md conventions as `project_context` and pass them to every agent automatically.

---

## What's in this repo

| File | Purpose |
|------|---------|
| [quickstart.md](quickstart.md) | Step-by-step setup (~2 hours). Start here. |
| [deep-dive.md](deep-dive.md) | Full pattern library — CLAUDE.md optimisation, doc splitting, annotation taxonomy, maintenance loops |
| [examples/](examples/) | Copy-pasteable templates: CLAUDE.md, docs/ai/README.md, .claude/rules/ |

---

## Related

- [ai-engineering-plugin](https://github.com/owenfranssen/ai-engineering-plugin) — skills for implementation once context is in place (flow, write-plan, investigate)
- [ai-engineering-feedback-loop](https://github.com/owenfranssen/ai-engineering-feedback-loop) — capture corrections from AI sessions, extract patterns, and promote them into rules; closes the loop that context engineering opens
- [Addy Osmani's agent-skills](https://github.com/addyosmani/agent-skills) — source-driven-development and other complementary skills
