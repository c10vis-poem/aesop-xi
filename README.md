# Æsop-Xi — Agentic Executions Split Operations Protocol

A device-agnostic protocol for running a **split** agent stack across the machines you
already own — mobile, workstation, home node, and cloud — behind **one shared, auditable
memory**.

> Aesop distilled a moral from every fable. **Æsop-Xi distills a strategy from every
> trajectory.**

## What it is

Æsop-Xi defines a small set of **agent roles**, four **memory types** (Declarative,
Recall, Strategic, and Working/Ephemeral — see `ARCHITECTURE.md` §4), and a set of
capability **tiers** that any hardware maps onto. Roles bind to tiers with graceful
fallback, so the same stack runs whether you have a phone + laptop + cloud, or a full
home-node rig. The specific hardware layout is a **profile**; the protocol itself is
device-agnostic.

## Agent roles

| Role | Job | Default tier |
| --- | --- | --- |
| **Query / tool-exec** | intake, meta-prompting, tool calls, reads memory | Edge (mobile) |
| **Executive** | heavy reasoning, direct file/memory access | Home node → Cloud |
| **Librarian / switchboard** | intercept prompts+outputs, select memory, log, **commit learnings back** (the flywheel) | Home node |
| **Auditor (red)** | independent gate on side-effecting actions; judges trajectories | Cloud (out-of-band) |

## Memory — four types, markdown as interchange

| Memory | Holds | Backed by |
| --- | --- | --- |
| **Declarative** | facts, "what things are" (source of truth) | wiki markdown — OpenWiki / Obsidian |
| **Recall** | semantic search across everything | OB1 / Open Brain (vector) |
| **Strategic** | distilled reasoning from successes **and** failures | ReasoningBank (fed by the auditor) |
| **Working / Ephemeral** | in-flight session/task state, deliberately not persisted | Redis |

Markdown is canonical and human-auditable; the vector indexes are **derived and
rebuildable** from it.

## Repo layout

Reflects what's actually on disk (2026-08-31), not the earlier aspirational
`clients/`/`agents/`/`memory/` layout that was never built:

```
aesop-xi/
  ARCHITECTURE.md      # the full protocol/orchestration/memory spec
  CLAUDE.md             # repo conventions for Claude Code sessions
  RESUME.md             # session handoff, full rewrite every session
  unresolved.md         # durable cross-session backlog
  protocol/             # tier definitions (tiers.md) + memory pointer (memory.md)
  profiles/             # hardware→tier mappings  ← personal
    _example.yaml       #   the common case: phone + laptop + cloud
    nav.yaml             #   a full 4-tier reference rig
  voice-engine/          # on-device terminal-agent voice pipeline — TEMPORARY,
                         # moves to the Æsc/Æyre daemon APKs once they exist
  deploy/                # per-tier bootstrap (phone/jetson/rubik-pi)
  Novus-Agenti/          # nested git repo, the Kotlin on-device client (Omni-Claw,
                         # §8) — not yet reconciled with the "NovusÆxenti" name in
                         # the broader naming family; treat as a separate project
                         # living inside this working tree, not a subdirectory of it
```

## Status

Private draft. `protocol/` is device-agnostic and intended for public release;
`profiles/` holds personal hardware mappings and stays private.
