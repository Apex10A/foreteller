-- Core cached football data + predictions (provider sync via service role).

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- competitions
-- ---------------------------------------------------------------------------

CREATE TABLE public.competitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id text NOT NULL,
  name text NOT NULL,
  slug text NOT NULL,
  country_code char(2),
  type text NOT NULL,
  season_label text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT competitions_provider_id_key UNIQUE (provider_id),
  CONSTRAINT competitions_slug_key UNIQUE (slug),
  CONSTRAINT competitions_type_check CHECK (
    type IN ('league', 'cup', 'friendly', 'other')
  )
);

CREATE INDEX competitions_is_active_idx ON public.competitions (is_active)
  WHERE is_active = true;

CREATE TRIGGER competitions_set_updated_at
  BEFORE UPDATE ON public.competitions
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

-- ---------------------------------------------------------------------------
-- teams
-- ---------------------------------------------------------------------------

CREATE TABLE public.teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id text NOT NULL,
  name text NOT NULL,
  short_name text,
  slug text NOT NULL,
  crest_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT teams_provider_id_key UNIQUE (provider_id),
  CONSTRAINT teams_slug_key UNIQUE (slug)
);

CREATE TRIGGER teams_set_updated_at
  BEFORE UPDATE ON public.teams
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

-- ---------------------------------------------------------------------------
-- fixtures
-- ---------------------------------------------------------------------------

CREATE TABLE public.fixtures (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id text NOT NULL,
  competition_id uuid NOT NULL REFERENCES public.competitions (id) ON DELETE RESTRICT,
  home_team_id uuid NOT NULL REFERENCES public.teams (id) ON DELETE RESTRICT,
  away_team_id uuid NOT NULL REFERENCES public.teams (id) ON DELETE RESTRICT,
  kickoff_at timestamptz NOT NULL,
  status text NOT NULL,
  home_score smallint,
  away_score smallint,
  matchday smallint,
  venue_name text,
  last_synced_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fixtures_provider_id_key UNIQUE (provider_id),
  CONSTRAINT fixtures_status_check CHECK (
    status IN (
      'scheduled',
      'live',
      'finished',
      'postponed',
      'cancelled',
      'abandoned'
    )
  ),
  CONSTRAINT fixtures_teams_distinct_chk CHECK (home_team_id <> away_team_id),
  CONSTRAINT fixtures_home_score_nonneg_chk CHECK (
    home_score IS NULL OR home_score >= 0
  ),
  CONSTRAINT fixtures_away_score_nonneg_chk CHECK (
    away_score IS NULL OR away_score >= 0
  ),
  CONSTRAINT fixtures_finished_scores_chk CHECK (
    status <> 'finished'
    OR (home_score IS NOT NULL AND away_score IS NOT NULL)
  ),
  CONSTRAINT fixtures_unplayed_scores_null_chk CHECK (
    status NOT IN ('scheduled', 'postponed', 'cancelled')
    OR (home_score IS NULL AND away_score IS NULL)
  )
);

CREATE INDEX fixtures_kickoff_at_idx ON public.fixtures (kickoff_at DESC);

CREATE INDEX fixtures_competition_kickoff_idx ON public.fixtures (
  competition_id,
  kickoff_at DESC
);

CREATE INDEX fixtures_status_kickoff_idx ON public.fixtures (status, kickoff_at);

CREATE INDEX fixtures_home_team_id_idx ON public.fixtures (home_team_id);

CREATE INDEX fixtures_away_team_id_idx ON public.fixtures (away_team_id);

CREATE TRIGGER fixtures_set_updated_at
  BEFORE UPDATE ON public.fixtures
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

-- ---------------------------------------------------------------------------
-- team_ratings
-- ---------------------------------------------------------------------------

CREATE TABLE public.team_ratings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid NOT NULL REFERENCES public.teams (id) ON DELETE RESTRICT,
  competition_id uuid REFERENCES public.competitions (id) ON DELETE RESTRICT,
  effective_at timestamptz NOT NULL,
  offensive_rating numeric(8, 4) NOT NULL,
  defensive_rating numeric(8, 4) NOT NULL,
  sample_size integer NOT NULL,
  source text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT team_ratings_sample_size_check CHECK (sample_size >= 0),
  CONSTRAINT team_ratings_source_check CHECK (
    source IN ('computed', 'provider', 'manual')
  )
);

CREATE UNIQUE INDEX team_ratings_global_snapshot_key ON public.team_ratings (
  team_id,
  effective_at
)
WHERE competition_id IS NULL;

CREATE UNIQUE INDEX team_ratings_competition_snapshot_key ON public.team_ratings (
  team_id,
  competition_id,
  effective_at
)
WHERE competition_id IS NOT NULL;

CREATE INDEX team_ratings_team_effective_idx ON public.team_ratings (
  team_id,
  effective_at DESC
);

CREATE INDEX team_ratings_comp_team_effective_idx ON public.team_ratings (
  competition_id,
  team_id,
  effective_at DESC
)
WHERE competition_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- predictions
-- ---------------------------------------------------------------------------

CREATE TABLE public.predictions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fixture_id uuid NOT NULL REFERENCES public.fixtures (id) ON DELETE RESTRICT,
  model_version text NOT NULL,
  home_win_prob numeric(5, 4) NOT NULL,
  draw_prob numeric(5, 4) NOT NULL,
  away_win_prob numeric(5, 4) NOT NULL,
  expected_home_goals numeric(6, 3),
  expected_away_goals numeric(6, 3),
  computed_at timestamptz NOT NULL DEFAULT now(),
  inputs_hash text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT predictions_fixture_model_key UNIQUE (fixture_id, model_version),
  CONSTRAINT predictions_home_win_prob_range_chk CHECK (
    home_win_prob >= 0
    AND home_win_prob <= 1
  ),
  CONSTRAINT predictions_draw_prob_range_chk CHECK (
    draw_prob >= 0
    AND draw_prob <= 1
  ),
  CONSTRAINT predictions_away_win_prob_range_chk CHECK (
    away_win_prob >= 0
    AND away_win_prob <= 1
  ),
  CONSTRAINT predictions_probs_sum_chk CHECK (
    abs(
      (home_win_prob + draw_prob + away_win_prob) - 1
    ) <= 0.0001
  )
);

CREATE INDEX predictions_computed_at_idx ON public.predictions (computed_at DESC);

CREATE TRIGGER predictions_set_updated_at
  BEFORE UPDATE ON public.predictions
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS: public read-only; writes via service role (bypasses RLS)
-- ---------------------------------------------------------------------------

ALTER TABLE public.competitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fixtures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.predictions ENABLE ROW LEVEL SECURITY;

CREATE POLICY competitions_public_read ON public.competitions
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY teams_public_read ON public.teams
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY fixtures_public_read ON public.fixtures
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY team_ratings_public_read ON public.team_ratings
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY predictions_public_read ON public.predictions
  FOR SELECT
  TO anon, authenticated
  USING (true);

GRANT SELECT ON public.competitions TO anon, authenticated;
GRANT SELECT ON public.teams TO anon, authenticated;
GRANT SELECT ON public.fixtures TO anon, authenticated;
GRANT SELECT ON public.team_ratings TO anon, authenticated;
GRANT SELECT ON public.predictions TO anon, authenticated;
