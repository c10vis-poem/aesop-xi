# AESOP Protocol — Tiers & Bindings

Device-agnostic. This file defines the tier contracts and how roles bind to them. A
user's hardware is declared separately in `profiles/`.

## Tier contracts

A profile assigns each declared node one or more tiers. To claim a tier, a node must
satisfy that tier's contract:

| Tier | Contract (must provide) |
| --- | --- |
| `edge` (T1) | a local small model or a passthrough connector; camera/mic access; a durable offline **action queue** for Tier-2 deferrals |
| `personal` (T2) | interactive terminal/browser; CPU-class compute |
| `home` (T3) | persistent storage; reachable over LAN/Tailscale whenever "home" is active; hosts the memory backends + gateway |
| `cloud` (T4) | on-demand compute; durable off-site storage; passthrough model access |

Any tier may be **absent**. Any node may claim **multiple** tiers. Multiple nodes may
**share** one tier.

## Role → tier binding

Each role names a preferred tier and an ordered fallback chain. The gateway binds to the
first **reachable** tier in the chain.

```yaml
roles:
  query:
    prefer: edge
    fallback: [personal]
  executive:
    prefer: home
    fallback: [cloud, personal]
  librarian:
    prefer: home
    fallback: [cloud]
  auditor:
    prefer: cloud          # out-of-band by default (independence)
    fallback: [home]        # local strict small model if no cloud
    edge_behavior: defer    # away with no auditor → self-audit T1, queue T2
```

## Audit tiers (write boundary)

```yaml
audit:
  tier0: none               # read / reason / info tool-calls
  tier1: self               # reversible local writes: adversarial self-pass + log
  tier2: independent        # irreversible/outbound + memory commits: require auditor
  offline_tier2: queue      # no auditor reachable → queue for audit-on-reconnect
```

## Memory bindings

```yaml
memory:
  declarative:              # source of truth
    format: markdown
    location: home          # canonical vault; cloud mirror for backup
  recall:
    backend: ob1            # vector + MCP
    derived_from: declarative
  strategic:
    backend: reasoning-bank
    writer: auditor         # only the judge writes; executor is blind
    embedder: local         # REQUIRED local in max-privacy profiles
```
