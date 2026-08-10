-- ============================================================
-- Bellabeat Case Study — Data Cleaning
-- All 7 tables, one file. Run via DBeaver or psql -f.
-- 3 independent datasets (fitbit, sleep_tracking, health_fitness) —
-- no shared user IDs, never joined, only compared in the write-up.
-- ============================================================


-- ================================================================
-- fitbit.dailyactivity_merged
-- Source: dailyActivity_merged.csv, two export folders concatenated
-- via bash head/tail (march-12-april-11-2016 + april-12-may-5-2016)
-- ================================================================

ALTER TABLE fitbit.dailyactivity_merged RENAME COLUMN "Id" TO id;
ALTER TABLE fitbit.dailyactivity_merged RENAME COLUMN "ActivityDate" TO activitydate;
ALTER TABLE fitbit.dailyactivity_merged RENAME COLUMN "TotalSteps" TO totalsteps;
ALTER TABLE fitbit.dailyactivity_merged RENAME COLUMN "TotalDistance" TO totaldistance;
ALTER TABLE fitbit.dailyactivity_merged RENAME COLUMN "VeryActiveMinutes" TO veryactiveminutes;
ALTER TABLE fitbit.dailyactivity_merged RENAME COLUMN "FairlyActiveMinutes" TO fairlyactiveminutes;
ALTER TABLE fitbit.dailyactivity_merged RENAME COLUMN "LightlyActiveMinutes" TO lightlyactiveminutes;
ALTER TABLE fitbit.dailyactivity_merged RENAME COLUMN "SedentaryMinutes" TO sedentaryminutes;
ALTER TABLE fitbit.dailyactivity_merged RENAME COLUMN "Calories" TO calories;

-- Nulls: 0 across id, activitydate, totalsteps.
SELECT COUNT(*) FILTER (WHERE id IS NULL) AS null_id,
       COUNT(*) FILTER (WHERE activitydate IS NULL) AS null_date,
       COUNT(*) FILTER (WHERE totalsteps IS NULL) AS null_steps
FROM fitbit.dailyactivity_merged;

-- Duplicates: 24 id+date pairs, all 2016-04-12 — the two source
-- folders overlap by one day. Keep the fuller day (higher active+
-- sedentary minute sum); 2 exact ties resolved via ctid.
DELETE FROM fitbit.dailyactivity_merged a
USING fitbit.dailyactivity_merged b
WHERE a.id = b.id AND a.activitydate = b.activitydate
  AND (a.veryactiveminutes + a.fairlyactiveminutes + a.lightlyactiveminutes + a.sedentaryminutes)
    < (b.veryactiveminutes + b.fairlyactiveminutes + b.lightlyactiveminutes + b.sedentaryminutes);

DELETE FROM fitbit.dailyactivity_merged a
USING fitbit.dailyactivity_merged b
WHERE a.id = b.id AND a.activitydate = b.activitydate AND a.ctid > b.ctid;
-- Result: 1397 -> 1373 rows. 0 duplicates remain.

ALTER TABLE fitbit.dailyactivity_merged
  ALTER COLUMN activitydate TYPE DATE USING TO_DATE(activitydate, 'MM/DD/YYYY'),
  ALTER COLUMN totalsteps TYPE INTEGER USING totalsteps::INTEGER,
  ALTER COLUMN totaldistance TYPE NUMERIC USING totaldistance::NUMERIC,
  ALTER COLUMN veryactiveminutes TYPE INTEGER USING veryactiveminutes::INTEGER,
  ALTER COLUMN fairlyactiveminutes TYPE INTEGER USING fairlyactiveminutes::INTEGER,
  ALTER COLUMN lightlyactiveminutes TYPE INTEGER USING lightlyactiveminutes::INTEGER,
  ALTER COLUMN sedentaryminutes TYPE INTEGER USING sedentaryminutes::INTEGER,
  ALTER COLUMN calories TYPE INTEGER USING calories::INTEGER;

-- Sanity: 9 rows with 0 steps/0 calories/1440 sedentary min —
-- device-not-worn days, not corrupt data. Kept, flagged for Analyze.
SELECT * FROM fitbit.dailyactivity_merged
WHERE totalsteps < 0 OR calories <= 0 OR totaldistance < 0;

-- Final: 1373 rows, 35 distinct ids, 2016-03-12 to 2016-05-12.


-- ================================================================
-- fitbit.sleepday_merged
-- Source: april-12-may-5-2016/sleepDay_merged.csv only — March
-- folder has no sleep file (real gap in the source).
-- ================================================================

ALTER TABLE fitbit.sleepday_merged RENAME COLUMN "Id" TO id;
ALTER TABLE fitbit.sleepday_merged RENAME COLUMN "SleepDay" TO sleepday;
ALTER TABLE fitbit.sleepday_merged RENAME COLUMN "TotalMinutesAsleep" TO totalminutesasleep;
ALTER TABLE fitbit.sleepday_merged RENAME COLUMN "TotalTimeInBed" TO totaltimeinbed;
ALTER TABLE fitbit.sleepday_merged RENAME COLUMN "TotalSleepRecords" TO totalsleeprecords;

-- Duplicates: 3 exact-duplicate id+date pairs (unrelated to the
-- folder-boundary pattern, cause unconfirmed). Drop one copy each.
DELETE FROM fitbit.sleepday_merged a
USING fitbit.sleepday_merged b
WHERE a.id = b.id AND a.sleepday = b.sleepday AND a.ctid > b.ctid;
-- Result: 413 -> 410 rows.
-- Open item: source CSV has 413 data rows (wc -l - 1) but DBeaver
-- imported 414 — a +1 discrepancy at import, untraced.

-- Sanity: time in bed must be >= minutes asleep, both within 0-1440.
SELECT * FROM fitbit.sleepday_merged
WHERE totalminutesasleep < 0 OR totaltimeinbed < 0
   OR totalminutesasleep > 1440 OR totaltimeinbed > 1440
   OR totalminutesasleep > totaltimeinbed;

-- Final: 410 rows, 24 distinct ids, 2016-04-12 to 2016-05-12.


-- ================================================================
-- fitbit.hourlysteps_merged + fitbit.hourlyintensities_merged
-- Same source-folder merge and boundary-overlap pattern as
-- dailyactivity_merged, at hourly grain.
-- ================================================================

ALTER TABLE fitbit.hourlysteps_merged RENAME COLUMN "Id" TO id;
ALTER TABLE fitbit.hourlysteps_merged RENAME COLUMN "ActivityHour" TO activityhour;
ALTER TABLE fitbit.hourlysteps_merged RENAME COLUMN "StepTotal" TO steptotal;

DELETE FROM fitbit.hourlysteps_merged a
USING fitbit.hourlysteps_merged b
WHERE a.id = b.id AND a.activityhour = b.activityhour AND a.ctid > b.ctid;

ALTER TABLE fitbit.hourlysteps_merged ALTER COLUMN steptotal TYPE INTEGER USING steptotal::INTEGER;

SELECT COUNT(*) FROM fitbit.hourlysteps_merged WHERE steptotal < 0;
-- Final: 46008 rows, 35 distinct ids.

ALTER TABLE fitbit.hourlyintensities_merged RENAME COLUMN "Id" TO id;
ALTER TABLE fitbit.hourlyintensities_merged RENAME COLUMN "ActivityHour" TO activityhour;
ALTER TABLE fitbit.hourlyintensities_merged RENAME COLUMN "TotalIntensity" TO totalintensity;
ALTER TABLE fitbit.hourlyintensities_merged RENAME COLUMN "AverageIntensity" TO averageintensity;

DELETE FROM fitbit.hourlyintensities_merged a
USING fitbit.hourlyintensities_merged b
WHERE a.id = b.id AND a.activityhour = b.activityhour AND a.ctid > b.ctid;

ALTER TABLE fitbit.hourlyintensities_merged
  ALTER COLUMN activityhour TYPE TIMESTAMP USING TO_TIMESTAMP(activityhour, 'MM/DD/YYYY HH12:MI:SS AM'),
  ALTER COLUMN totalintensity TYPE INTEGER USING totalintensity::INTEGER,
  ALTER COLUMN averageintensity TYPE NUMERIC USING averageintensity::NUMERIC;
-- Final: 45975 rows — NOT 46008 like hourlysteps_merged. 33-row gap,
-- unexplained (duplicate count before delete was never captured).


-- ================================================================
-- fitbit.heartrate_seconds_merged
-- Excluded from full cleaning: 3.6M+ raw rows need aggregation
-- before use anyway, and heart rate covers far fewer users (15)
-- than the activity tables (35). Cleaned enough for a safe daily
-- aggregate, not treated as general-purpose.
-- ================================================================

CREATE INDEX IF NOT EXISTS idx_heartrate_id_time ON fitbit.heartrate_seconds_merged ("Id", "Time");

ALTER TABLE fitbit.heartrate_seconds_merged
  RENAME COLUMN "Id" TO id,
  RENAME COLUMN "Time" TO time,
  RENAME COLUMN "Value" TO value;

-- Direct GROUP BY on (id,time) too slow at this scale — confirm the
-- boundary overlap via per-day counts instead, then drop duplicates.
DELETE FROM fitbit.heartrate_seconds_merged a
USING fitbit.heartrate_seconds_merged b
WHERE a.id = b.id AND a.time = b.time AND a.ctid > b.ctid;

ALTER TABLE fitbit.heartrate_seconds_merged
  ALTER COLUMN time TYPE TIMESTAMP USING TO_TIMESTAMP(time, 'MM/DD/YYYY HH12:MI:SS AM'),
  ALTER COLUMN value TYPE INTEGER USING value::INTEGER;

SELECT COUNT(*) FILTER (WHERE id IS NULL) AS null_id,
       COUNT(*) FILTER (WHERE time IS NULL) AS null_time,
       COUNT(*) FILTER (WHERE value IS NULL) AS null_value
FROM fitbit.heartrate_seconds_merged;

SELECT COUNT(*) FROM fitbit.heartrate_seconds_merged WHERE value < 30 OR value > 220;
-- Final: 3,614,915 rows, 15 distinct ids, 2016-03-12 to 2016-05-12.
-- Use the daily aggregate (sql/02_analysis.sql) for anything
-- downstream, not this raw table.


-- ================================================================
-- sleep_tracking.smartwatch_sleep_dataset
-- Independent dataset, no shared IDs with FitBit. Every column
-- imported with the correct type already — no conversion needed.
-- ================================================================

-- Duplicates on (user_id, date_recorded): 38 pairs. Bucketed by the
-- time gap between each pair's two sleep_start_timestamp values —
-- not all "duplicates" are the same kind of problem.
WITH pair_gaps AS (
  SELECT user_id, date_recorded,
    EXTRACT(EPOCH FROM (MAX(sleep_start_timestamp) - MIN(sleep_start_timestamp))) / 60 AS gap_minutes
  FROM sleep_tracking.smartwatch_sleep_dataset
  WHERE (user_id, date_recorded) IN (
    SELECT user_id, date_recorded FROM sleep_tracking.smartwatch_sleep_dataset
    GROUP BY user_id, date_recorded HAVING COUNT(*) > 1)
  GROUP BY user_id, date_recorded
)
SELECT
  CASE WHEN gap_minutes = 0 THEN '0 min - true duplicate'
       WHEN gap_minutes < 120 THEN 'under 2h - near-duplicate/noise'
       WHEN gap_minutes < 720 THEN '2-12h - ambiguous, left alone'
       ELSE 'over 12h - legitimate separate sessions, left alone' END AS gap_bucket,
  COUNT(*) AS n_pairs
FROM pair_gaps GROUP BY 1 ORDER BY 1;
-- Result: 1 identical / 21 under 2h / 4 ambiguous / 12 over 12h.

-- Resolve the 22 pairs (identical + under 2h): keep the row with the
-- longer duration_minutes (closer to a complete sleep record).
DELETE FROM sleep_tracking.smartwatch_sleep_dataset a
USING sleep_tracking.smartwatch_sleep_dataset b
WHERE a.user_id = b.user_id AND a.date_recorded = b.date_recorded AND a.ctid <> b.ctid
  AND EXTRACT(EPOCH FROM (GREATEST(a.sleep_start_timestamp, b.sleep_start_timestamp)
      - LEAST(a.sleep_start_timestamp, b.sleep_start_timestamp))) / 60 < 120
  AND a.duration_minutes < b.duration_minutes;

DELETE FROM sleep_tracking.smartwatch_sleep_dataset a
USING sleep_tracking.smartwatch_sleep_dataset b
WHERE a.user_id = b.user_id AND a.date_recorded = b.date_recorded
  AND EXTRACT(EPOCH FROM (GREATEST(a.sleep_start_timestamp, b.sleep_start_timestamp)
      - LEAST(a.sleep_start_timestamp, b.sleep_start_timestamp))) / 60 < 120
  AND a.ctid > b.ctid;
-- Result: 20000 -> 19978 rows.

-- heart_rate_mean_bpm checked after a small sample looked suspiciously
-- uniform. Full distribution (36.4-98.4, avg 60.1, stddev 7.5) is a
-- normal range — clean. But it's flat across every age bucket and
-- device model: the dataset doesn't model age/fitness correlation
-- with sleeping heart rate. Usable, just not for an age-effect claim.

-- Remaining sanity checks
SELECT * FROM sleep_tracking.smartwatch_sleep_dataset
WHERE sleep_efficiency_pct NOT BETWEEN 0 AND 100
   OR sleep_stage_deep_pct NOT BETWEEN 0 AND 100
   OR sleep_stage_light_pct NOT BETWEEN 0 AND 100
   OR sleep_stage_rem_pct NOT BETWEEN 0 AND 100
   OR sleep_stage_awake_pct NOT BETWEEN 0 AND 100
   OR duration_minutes <= 0 OR duration_minutes > 720
   OR spo2_mean_pct NOT BETWEEN 70 AND 100
   OR spo2_min_pct NOT BETWEEN 70 AND 100
   OR movement_count < 0 OR snore_events < 0 OR step_count_day < 0
   OR caffeine_mg < 0 OR alcohol_units < 0
   OR age NOT BETWEEN 1 AND 100;

-- Final: 19978 rows.


-- ================================================================
-- health_fitness.health_fitness_dataset
-- Headers already snake_case in the source CSV — no renames needed.
-- ================================================================

SELECT
  COUNT(*) FILTER (WHERE participant_id IS NULL) AS null_participant_id,
  COUNT(*) FILTER (WHERE date IS NULL) AS null_date,
  COUNT(*) FILTER (WHERE age IS NULL) AS null_age,
  COUNT(*) FILTER (WHERE daily_steps IS NULL) AS null_steps,
  COUNT(*) FILTER (WHERE sleep_hours IS NULL) AS null_sleep_hours,
  COUNT(*) FILTER (WHERE stress_level IS NULL) AS null_stress
FROM health_fitness.health_fitness_dataset;

SELECT participant_id, date, COUNT(*)
FROM health_fitness.health_fitness_dataset
GROUP BY participant_id, date HAVING COUNT(*) > 1;

ALTER TABLE health_fitness.health_fitness_dataset
  ALTER COLUMN date TYPE DATE USING TO_DATE(date, 'YYYY-MM-DD'),
  ALTER COLUMN age TYPE INTEGER USING age::INTEGER,
  ALTER COLUMN duration_minutes TYPE INTEGER USING duration_minutes::INTEGER,
  ALTER COLUMN calories_burned TYPE INTEGER USING calories_burned::INTEGER,
  ALTER COLUMN daily_steps TYPE INTEGER USING daily_steps::INTEGER,
  ALTER COLUMN sleep_hours TYPE NUMERIC USING sleep_hours::NUMERIC,
  ALTER COLUMN stress_level TYPE INTEGER USING stress_level::INTEGER;

-- Sanity: 2 rows with negative daily_steps (-419, -81) — set to NULL
-- rather than dropped, rest of the row stays usable.
UPDATE health_fitness.health_fitness_dataset
  SET daily_steps = NULL WHERE daily_steps < 0;

-- Row-count gap check: raw CSV note says 687,702; table has 687,701.
-- Confirmed NOT a duplicate hiding in the table (distinct_rows =
-- total_rows below) — gap traces to the raw file/import, not this
-- cleaning pass (only write here was an UPDATE, not a DELETE).
SELECT COUNT(*) AS total_rows,
  COUNT(DISTINCT (participant_id, date, age, gender, activity_type, duration_minutes,
    intensity, calories_burned, daily_steps, sleep_hours, stress_level,
    health_condition, fitness_level)) AS distinct_rows
FROM health_fitness.health_fitness_dataset;

-- calories_burned is session-level (one row = one logged exercise
-- event, alongside duration_minutes/intensity/activity_type), NOT a
-- daily total. Comparing its raw average to FitBit's daily calorie
-- average was comparing two different things — corrected in
-- 02_analysis.sql to report avg calories per session instead.

-- hydration_level (daily water intake, liters) — the reason this
-- dataset was sourced (Spring angle). Confirmed present and clean.
-- Gender breakdown in 02_analysis.sql: F 2.50L, M 2.50L, Other 2.49L
-- — no meaningful difference. The gender-hydration story this
-- dataset was chosen to find isn't in the data.

-- Final: 687701 rows, 3000 distinct participants, 2024-01-01 to 2024-12-12.
