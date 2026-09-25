# D.U.M.B.A.S.S. Orchestration Contract

**Status:** DRAFT v0.1 (2026-09-25), awaiting operator approval. No OmniRoute code is written against
this until it is approved. Scope: the runtime loop every agent request goes through. The finished
Æsop-Xi agent's own memory model stays in `ARCHITECTURE.md` §4 / `protocol/memory.md`.

**Sources read for this draft:** OmniRoute fork `c10vis-poem/NvAEx-OmniRoute` @ `f4afc71` —
`docs/frameworks/{PLUGIN_SDK,PLUGINS,AGENT-SKILLS,LOCAL_CORPUS_CONTEXT,OBSIDIAN_CONTEXT}.md` in full;
`SKILLS.md` §1–130 + custom-skill section; `MEMORY.md` overview, injection, MemoryBackend pattern;
`docs/compression/{COMPRESSION_ENGINES,EXTENDING_COMPRESSION}.md` in full. mem0 fork `server/`
(compose, `.env.example`, `README.md`, `main.py` config). Planning set
`Documents/Dumbass_cloud_config/01–07.md` in full. Live VM services (each round-trip tested).
**Not read:** OmniRoute `MCP-SERVER.md`, `A2A-SERVER.md`, `EVALS.md` body, `WEBHOOKS.md`,
`PLUGIN_MARKETPLACE.md`; Hermes / Qwen Code / Graphify / notebooklm-py source. Claims that depend on
those are marked **OPEN**.

---

## 1. Roles

| Component | What it is | Runs where | Owns | State |
|---|---|---|---|---|
| Agent harness (Claude Code, Hermes, Qwen Code, OpenWiki) | Agent loop + UI | phone / tablet / VM desktop | the conversation | per device |
| **Honey-for-devs** | Output discipline + compression, two halves (§3.1) | harness skill **and** OmniRoute engine | token budget | skill: on phone from the plugin marketplace (greenpt/honey 1.3.1), **not the fork** — reinstall from fork; engine: **to build** |
| **Task Observer** | Skill-improvement methodology (§3.2) | harness skill + OmniRoute tool | the observation log | skill: on phone (source vs. fork unverified); tool: **to build** |
| **OmniRoute** | Gateway / control plane: auth, routing, compression, memory, skills, MCP | VM Docker, `127.0.0.1:20128` | provider keys, routing policy | building from fork |
| **Terrestrial Brain** | Static corpus retrieval (arm 1) | VM, MCP `:8000`, header `x-brain-key` | Postgres `terrestrial_brain` | live |
| **code-review-graph** | Code graph + vector retrieval (arm 2) | VM, MCP `:5555` | per-repo SQLite | live |
| **mem0** | Episodic memory (arm 3) | VM, REST `:8888` + dashboard `:3000` | Postgres `mem0`, `mem0_app` | fork merged, service **to start** |
| **Reasoning Bank** | Success-verified trajectory ledger (§3.4) | OmniRoute plugin | JSONL → Postgres `reasoning_bank` | **to build** |
| **Continual Harness** | Session checkpoint / rollback (§3.5) | OmniRoute plugin | per-session checkpoints | **to build** |
| Vault | Source of truth (GitSync → `c10vis-poem/NovAExorpus`) | phone, tablet, VM `~/vault` | all authored knowledge | live |
| Neo4j | Graph store | VM `127.0.0.1:7687` | nothing yet | installed, **no consumer** |

Rule: **only OmniRoute holds provider API keys.** Services that need an LLM or embeddings
(Terrestrial Brain, mem0) call OmniRoute's OpenAI-compatible endpoint with their own OmniRoute key.

---

## 2. The request loop

```
[0] harness launch ── Honey skill + Task Observer skill loaded into the agent's context
[1] agent → OmniRoute /v1  (per-harness OmniRoute API key; REQUIRE_API_KEY=true)
[2] onRequest plugins, by priority (lower first)
      p20  continual-harness   attach this session's checkpoint (if any)       [modifyBody]
      p40  reasoning-bank      open a trajectory record for this request        [addMetadata]
[3] memory injection  (OmniRoute MemoryBackend → mem0; OPT-IN per key, ~2k tokens/request)
[4] skill injection   (Omni Skills: observation_log tool, mode=auto)
[5] compression       stacked pipeline: rtk → honey   (Caveman removed from the default path)
[6] route → provider  (OpenRouter / frontier accounts), fallback per OmniRoute combos
[7] tool calls        agent-pulled retrieval: Terrestrial Brain, code-review-graph MCP tools;
                      Obsidian context (read-only scope); Local Corpus (lexical fallback)
[8] onResponse / onStreamEnd
      reasoning-bank      close the record: outcome, tools used, verification evidence
      continual-harness   update the session checkpoint
      memory extraction   facts → mem0 (only when [3] is enabled for this key)
[9] response to agent  (output style per §4)
```

Retrieval policy: **episodic memory is pushed** (step 3, opt-in); **corpus and code retrieval are
pulled** (step 7, the agent calls tools when it needs them). Pushing every arm into every request
would multiply token cost for requests that don't need it.

---

## 3. Component contracts

### 3.1 Honey-for-devs
- **Harness half:** installed from `c10vis-poem/NoVa-honey-for-devs` into every harness
  (`honey-install`). Governs how much the agent *writes*.
- **OmniRoute half:** a compression engine `id: "honey"` registered through OmniRoute's documented
  engine interface (`id`, `compress`, `getConfigSchema`, `validateConfig`, `stackable: true`,
  `targets: ["messages","tool_results"]`). Governs how much gets *sent*. Uses Honey's `eson`
  codec for uniform JSON/tool-result arrays and Honey's terse prose rules for messages.
  Code blocks, identifiers, paths, errors, and secrets-handling text are never altered.
- Pipeline: `mode: "stacked"`, `stackedPipeline: [rtk, honey]`. RTK stays: it is the only
  engine with command-output filters.
- Acceptance: OmniRoute `/api/compression/preview` shows savings on a fixed sample set, and the
  compression test gates in `COMPRESSION_ENGINES.md` still pass.
- **OPEN:** how a custom engine is loaded in the Docker image (`~/.omniroute/compression/engines/`
  vs. a fork source change). Decide by reading `strategySelector.ts` before building.

### 3.2 Task Observer
- **Harness half:** the skill (`c10vis-poem/aesop-task-observer`) in every harness, plus the
  activation line in that harness's instruction file.
- **OmniRoute half:** an Omni Skill tool `observation_log@1.0.0` (custom handler, `mode: auto`)
  that appends one observation to **a single shared store**. This replaces the two diverged
  per-device logs found on 2026-09-25 (`~/.claude/skill-observations/` and
  `~/.claude/projects/-data-data-com-termux-files-home/skill-observations/`).
- Record schema = the skill's existing frontmatter (`id, title, status, type, skill,
  proposes_skill, siblings_checked, area, date, session_context`) + `device`, `harness`.
- Acceptance: two different harnesses log through the tool; both entries appear in one listing.

### 3.3 Retrieval arms
| Arm | Interface | Auth | Query shape | Writes |
|---|---|---|---|---|
| Terrestrial Brain | MCP `http://127.0.0.1:8000/mcp` | `x-brain-key` | `search_thoughts`, projects, documents… | via its own tools only |
| code-review-graph | MCP `http://127.0.0.1:5555/mcp` | local-only | `query_graph`, `get_impact_radius`, `semantic_search_nodes`… | graph builds only |
| mem0 | REST `:8888` + OmniRoute `GenericMemoryBackend` | `X-API-Key` | search / add memories | episodic facts only |

- All three index **from** the vault/repos and are rebuildable from them. None writes to the vault.
- **OPEN:** whether OmniRoute's MCP server can front external MCP servers (so agents need one
  endpoint instead of three). Until verified, harnesses connect to the TB and CRG MCP endpoints
  directly over Tailscale.

### 3.4 Reasoning Bank
- OmniRoute plugin `reasoning-bank`, hooks `onRequest` (p40), `onResponse`, `onStreamEnd`,
  `onError`; permissions `file-write` only.
- Writes one JSONL record per request to `DATA_DIR/reasoning_bank/candidates/` with `requestId`,
  session, harness, model/provider, tools called, token counts, outcome.
- **Promotion rule (Success Verification Grade):** a candidate becomes a *verified success* only
  with evidence: tests/CI passed, a merged PR, or explicit operator acceptance. Failures go to
  `failure_logs/` as regression fixtures and are **never** positive training data.
- Batch loader (home node, later) moves verified records into Postgres `reasoning_bank`.
- **OPEN:** whether plugin sandboxes keep state across hooks (needed to pair request↔response);
  fallback is keying everything on `requestId` in the file.

### 3.5 Continual Harness
- OmniRoute plugin `continual-harness`, hooks `onRequest` (p20) and `onResponse`.
- Session identity: request header `x-dumbass-session` (set by the harness).
- On request: if a checkpoint exists for the session, prepend a compact checkpoint block (goal,
  done, next, open questions) via `modifyBody`. On response: update the checkpoint.
- Rollback: keep the last N checkpoints per session; a harness can request `?checkpoint=<n>`.
- Checkpoints are working state, never durable truth, and are never written to the vault.

### 3.6 Vault and context sources
- Obsidian context (22 MCP tools): **read scope by default**, write scope only on named keys.
  OmniRoute's WebDAV vault sync stays **off** (GitSync Portal already syncs the vault).
- Local Corpus: pointed at the VM vault clone as a cheap lexical fallback (limits: 5,000 files,
  64 MiB; current vault is ~1,323 files / 66 MB, so it may need a narrower root).

---

## 4. Output style

- **To a human:** Honey terse: answer first, no filler, exact code/paths/commands.
- **Agent → agent / tool results:** minified JSON; uniform arrays in columnar form
  (`{"c":[...],"r":[[...]]}`); `eson` only for high-volume cached pipes.
- **Every task result** closes with: `outcome` (success / partial / failed), `evidence`
  (commands run + results), `files_changed`, `open_items`. This is what Reasoning Bank grades.

---

## 5. Identity, security, cost

- One OmniRoute API key per harness per device; scopes are the minimum each harness needs.
- All service ports bind `127.0.0.1`; devices reach them over Tailscale only. GCP firewall: SSH only.
- Secrets live in `/opt/dumbass/*.env` (mode 600), never in unit files or repos.
- Memory injection (step 3) is opt-in per key, because it adds tokens to every request.
- The VM runs only while in use: 30-min idle auto-off + 4 AM hard stop; no other scheduled jobs.

---

## 6. Build order (after approval)

1. Start OmniRoute (fork build) + mem0 server; point TB and mem0 LLM calls at OmniRoute.
2. `honey` compression engine → preview savings → set stacked pipeline.
3. `reasoning-bank` + `continual-harness` plugins, each with tests in the fork.
4. `observation_log` Omni Skill; merge the two existing observation logs into it.
5. mem0 as OmniRoute `GenericMemoryBackend`, opt-in on one key, measure token cost.
6. Harness installs (Honey + Task Observer + OmniRoute key) on phone, tablet, VM.

Each step ships as a PR on the relevant fork with CI green, per the fork workflow.
