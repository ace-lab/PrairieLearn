ALTER TABLE assessments ADD COLUMN IF NOT EXISTS max_bonus_points DOUBLE PRECISION;
ALTER TABLE assessment_instances ADD COLUMN IF NOT EXISTS max_bonus_points DOUBLE PRECISION;
