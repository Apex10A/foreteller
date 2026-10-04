-- Competition membership / cached standings + cron sync watermarks.

-- ---------------------------------------------------------------------------
-- competition_teams
-- ---------------------------------------------------------------------------

CREATE TABLE public.competition_teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competition_id uuid NOT NULL REFERENCES public.competitions (id) ON DELETE RESTRICT,
  team_id uuid NOT NULL REFERENCES public.teams (id) ON DELETE RESTRICT,
  provider_id text,
  standing_position smallint,
  played smallint NOT NULL DEFAULT 0,
  won smallint NOT NULL DEFAULT 0,
  drawn smallint NOT NULL DEFAULT 0,
  lost smallint NOT NULL DEFAULT 0,
  goals_for smallint NOT NULL DEFAULT 0,
  goals_against smallint NOT NULL DEFAULT 0,
  goal_difference smallint NOT NULL DEFAULT 0,
  points smallint NOT NULL DEFAULT 0,
  last_synced_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT competition_teams_competition_team_key UNIQUE (competition_id, team_id),
  CONSTRAINT competition_teams_provider_id_key UNIQUE (provider_id),
  CONSTRAINT competition_teams_standing_position_nonneg_chk CHECK (
    standing_position IS NULL OR standing_position > 0
  ),
  CONSTRAINT competition_teams_played_nonneg_chk CHECK (played >= 0),
  CONSTRAINT competition_teams_won_nonneg_chk CHECK (won >= 0),
  CONSTRAINT competition_teams_drawn_nonneg_chk CHECK (drawn >= 0),
  CONSTRAINT competition_teams_lost_nonneg_chk CHECK (lost >= 0),
  CONSTRAINT competition_teams_goals_for_nonneg_chk CHECK (goals_for >= 0),
  CONSTRAINT competition_teams_goals_against_nonneg_chk CHECK (goals_against >= 0),
  CONSTRAINT competition_teams_points_nonneg_chk CHECK (points >= 0)
);

CREATE INDEX competition_teams_competition_standing_idx ON public.competition_teams (
  competition_id,
  standing_position
)
WHERE standing_position IS NOT NULL;

CREATE INDEX competition_teams_team_id_idx ON public.competition_teams (team_id);

CREATE TRIGGER competition_teams_set_updated_at
  BEFORE UPDATE ON public.competition_teams
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

-- ---------------------------------------------------------------------------
-- sync_cursors (idempotent cron / provider pagination watermarks)
-- ---------------------------------------------------------------------------

CREATE TABLE public.sync_cursors (
  job_key text PRIMARY KEY,
  cursor_value text,
  last_success_at timestamptz,
  last_error text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sync_cursors_job_key_format_chk CHECK (
    job_key ~ '^[a-z][a-z0-9_]*(:[a-z0-9_-]+)*$'
  )
);

CREATE TRIGGER sync_cursors_set_updated_at
  BEFORE UPDATE ON public.sync_cursors
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.competition_teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_cursors ENABLE ROW LEVEL SECURITY;

CREATE POLICY competition_teams_public_read ON public.competition_teams
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Sync state is server-only; no public read policy on sync_cursors.

GRANT SELECT ON public.competition_teams TO anon, authenticated;
