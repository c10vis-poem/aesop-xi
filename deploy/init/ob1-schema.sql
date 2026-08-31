-- AESOP T3 — OB1/Open Brain schema
-- Runs automatically on first Postgres container start.
-- Mirrors OB1's Supabase setup (docs/01-getting-started.md) but self-hosted.

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- ── Thoughts table (Recall Memory) ──────────────────────────────
-- Stores raw thoughts, sources, cross-domain searchable content.
-- OB1/Open Brain's core table — any AI tool reads/writes via MCP.
CREATE TABLE IF NOT EXISTS thoughts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  content text NOT NULL,
  embedding vector(1536),
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- HNSW index for fast vector similarity search
CREATE INDEX IF NOT EXISTS idx_thoughts_embedding
  ON thoughts USING hnsw (embedding vector_cosine_ops);

-- GIN index for filtering by metadata fields
CREATE INDEX IF NOT EXISTS idx_thoughts_metadata
  ON thoughts USING gin (metadata);

-- B-tree index for date range queries
CREATE INDEX IF NOT EXISTS idx_thoughts_created_at
  ON thoughts (created_at DESC);

-- Auto-update updated_at on row modification
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS trigger AS $$
BEGIN
  new.updated_at = now();
  return new;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS thoughts_updated_at ON thoughts;
CREATE TRIGGER thoughts_updated_at
  BEFORE UPDATE ON thoughts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- ── Strategies table (Strategic Memory — ReasoningBank) ─────────
-- Distilled reasoning patterns from successes and failures.
-- Fed by the auditor's verdict → reward signal.
CREATE TABLE IF NOT EXISTS strategies (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  query text,
  think_list jsonb,
  action_list jsonb,
  status text,
  reward integer,
  embedding vector(1536),
  distilled text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_strategies_embedding
  ON strategies USING hnsw (embedding vector_cosine_ops);

CREATE INDEX IF NOT EXISTS idx_strategies_metadata
  ON strategies USING gin (metadata);

CREATE INDEX IF NOT EXISTS idx_strategies_created_at
  ON strategies (created_at DESC);

DROP TRIGGER IF EXISTS strategies_updated_at ON strategies;
CREATE TRIGGER strategies_updated_at
  BEFORE UPDATE ON strategies
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- ── Audit log table (Tier 1/2 write gate) ────────────────────────
-- OmniRoute's mcp_audit table shape, for the AESOP audit gate (§5).
CREATE TABLE IF NOT EXISTS audit_log (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  tier integer NOT NULL,
  action text NOT NULL,
  agent_role text,
  trajectory jsonb,
  verdict text,
  reward integer,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_tier
  ON audit_log (tier);

CREATE INDEX IF NOT EXISTS idx_audit_log_created_at
  ON audit_log (created_at DESC);
