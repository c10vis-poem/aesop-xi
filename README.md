# AESOP — Agentic Executions Split Operations Protocol

A device-agnostic protocol for running a **split** agent stack across the machines you
already own — mobile, workstation, home node, and cloud — behind **one shared, auditable
memory**.

> Aesop distilled a moral from every fable. **AESOP distills a strategy from every
> trajectory.**

## What it is

AESOP defines a small set of **agent roles**, three **memory types**, and a set of
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

## Memory — three types, markdown as interchange

| Memory | Holds | Backed by |
| --- | --- | --- |
| **Declarative** | facts, "what things are" (source of truth) | wiki markdown — OpenWiki / Obsidian |
| **Recall** | semantic search across everything | OB1 / Open Brain (vector) |
| **Strategic** | distilled reasoning from successes **and** failures | ReasoningBank (fed by the auditor) |

Markdown is canonical and human-auditable; the vector indexes are **derived and
rebuildable** from it.

## Repo layout

```
aesop/
  ARCHITECTURE.md      # the full spec
  protocol/            # tier definitions + role→tier bindings + fallback  ← device-agnostic, public
  profiles/            # hardware→tier mappings  ← personal
    _example.yaml      #   the common case: phone + laptop + cloud
    nav.yaml           #   a full 4-tier reference rig
  clients/omni-claw/   # on-device UI / client layer
  agents/              # query · executive · librarian · auditor contracts
  memory/              # wiki + OB1 + reasoning-bank adapters
  deploy/              # per-tier bootstrap
```

## Status

Private draft. `protocol/` is device-agnostic and intended for public release;
`profiles/` holds personal hardware mappings and stays private.
