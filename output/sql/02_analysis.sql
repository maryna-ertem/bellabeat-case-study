-- ============================================================
-- Bellabeat Case Study — Analysis & Export
-- Run after 01_clean_data.sql. Results below are confirmed from
-- actual runs — this is the source of truth for the README's
-- Analyze section. Export section at the bottom needs psql -f,
-- not DBeaver (\COPY is a psql client command).
-- ============================================================


-- ================================================================
-- fitbit.dailyactivity_merged
-- ================================================================
SELECT COUNT(*) FROM fitbit.dailyactivity_merged; -- 1373
SELECT COUNT(DISTINCT id) FROM fitbit.dailyactivity_merged; -- 35
SELECT MIN(activitydate), MAX(activitydate) FROM fitbit.dailyactivity_merged; -- 2016-03-12 to 2016-05-12

SELECT COUNT(*) AS worn_inactive_days,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fitbit.dailyactivity_merged), 1) AS pct_of_rows
FROM fitbit.dailyactivity_merged WHERE totalsteps = 0 AND calories > 0;
-- 127 rows, 9.2%

SELECT COUNT(*) AS not_worn_days,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fitbit.dailyactivity_merged), 1) AS pct_of_rows
FROM fitbit.dailyactivity_merged WHERE totalsteps = 0 AND calories = 0;
-- 9 rows, 0.7%

SELECT
  ROUND(AVG(totalsteps)) AS avg_steps, MIN(totalsteps) AS min_steps, MAX(totalsteps) AS max_steps,
  ROUND(AVG(calories)) AS avg_calories, ROUND(AVG(sedentaryminutes)) AS avg_sedentary_min,
  ROUND(AVG(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes)) AS avg_active_min
FROM fitbit.dailyactivity_merged;
-- avg_steps 7359 | min 0 | max 36019 | avg_calories 2290 | avg_sedentary_min 1002 | avg_active_min 221

SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE totalsteps >= 10000) / COUNT(*), 1) AS pct_days_10k_steps
FROM fitbit.dailyactivity_merged; -- 31.3%

SELECT EXTRACT(HOUR FROM activityhour::timestamp) AS hour_of_day, ROUND(AVG(steptotal)) AS avg_steps
FROM fitbit.hourlysteps_merged GROUP BY hour_of_day ORDER BY hour_of_day;
-- Lowest 3am (7 steps), highest 7pm (555 steps).


-- Average Steps (User-Level Aggregation)
-- Averages the steps per user first, preventing hyper-active users 
-- with more logged days from skewing the total population average.
WITH user_averages AS (
  SELECT 
    id, 
    AVG(totalsteps) AS avg_user_steps
  FROM fitbit.dailyactivity_merged
  GROUP BY id
)
SELECT 
  ROUND(AVG(avg_user_steps)) AS true_cohort_avg_steps
FROM user_averages;
-- 7060


-- Wear Compliance & Device Retention Analysis
-- Evaluates user drop-off by counting how many distinct days each user 
-- actively wore the device (logged > 0 steps).
WITH user_wear_days AS (
  SELECT 
    id, 
    COUNT(activitydate) AS days_worn
  FROM fitbit.dailyactivity_merged
  WHERE totalsteps > 0
  GROUP BY id
)
SELECT 
  CASE 
    WHEN days_worn < 15 THEN '1. Low Retention (<15 days)'
    WHEN days_worn <= 30 THEN '2. Medium Retention (15-30 days)'
    ELSE '3. High Retention (31+ days)'
  END AS retention_bucket,
  COUNT(id) AS total_users,
  ROUND(100.0 * COUNT(id) / (SELECT COUNT(DISTINCT id) FROM fitbit.dailyactivity_merged), 1) AS pct_of_total_users
FROM user_wear_days
GROUP BY retention_bucket
ORDER BY retention_bucket;
-- Low retention - 2 users, 5.7% of total; Medioum retention 8 users 22.9%; High retention - 25 users, 71.4%

-- ================================================================
-- fitbit.sleepday_merged
-- ================================================================
SELECT COUNT(*) FROM fitbit.sleepday_merged; -- 410
SELECT COUNT(DISTINCT id) FROM fitbit.sleepday_merged; -- 24
SELECT MIN(sleepday), MAX(sleepday) FROM fitbit.sleepday_merged; -- 2016-04-12 to 2016-05-12

SELECT
  ROUND(AVG(totalminutesasleep) / 60.0, 1) AS avg_hours_asleep,
  ROUND(AVG(totaltimeinbed) / 60.0, 1) AS avg_hours_in_bed,
  ROUND(AVG(100.0 * totalminutesasleep / NULLIF(totaltimeinbed, 0)), 1) AS avg_sleep_efficiency_pct
FROM fitbit.sleepday_merged;
-- avg_hours_asleep 7.0 | avg_hours_in_bed 7.6 | avg_sleep_efficiency_pct 91.6

SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE totalminutesasleep < 420) / COUNT(*), 1) AS pct_nights_under_7h
FROM fitbit.sleepday_merged; -- 44.1%

SELECT COUNT(DISTINCT s.id) AS users_with_sleep_data,
  (SELECT COUNT(DISTINCT id) FROM fitbit.dailyactivity_merged) AS total_users,
  ROUND(100.0 * COUNT(DISTINCT s.id) / (SELECT COUNT(DISTINCT id) FROM fitbit.dailyactivity_merged), 1) AS pct_adoption
FROM fitbit.sleepday_merged s; -- 24 of 35, 68.6% adoption


-- ================================================================
-- fitbit.hourlyintensities_merged, fitbit.heartrate_seconds_merged
-- ================================================================
SELECT COUNT(*) FROM fitbit.hourlyintensities_merged; -- 45975
SELECT ROUND(AVG(totalintensity), 1) AS avg_total_intensity, ROUND(AVG(averageintensity), 2) AS avg_average_intensity
FROM fitbit.hourlyintensities_merged; -- 11.4, 0.19

SELECT COUNT(*) FROM fitbit.heartrate_seconds_merged; -- 3614915
SELECT COUNT(DISTINCT id) FROM fitbit.heartrate_seconds_merged; -- 15

-- Daily aggregate — use this, not the raw 3.6M rows, for anything downstream.
SELECT id, DATE(time) AS day, ROUND(AVG(value)) AS avg_hr, MIN(value) AS min_hr, MAX(value) AS max_hr
FROM fitbit.heartrate_seconds_merged GROUP BY id, DATE(time);


-- ================================================================
-- health_fitness.health_fitness_dataset
-- ================================================================
SELECT COUNT(*) FROM health_fitness.health_fitness_dataset; -- 687701
SELECT COUNT(DISTINCT participant_id) FROM health_fitness.health_fitness_dataset; -- 3000
SELECT MIN(date), MAX(date) FROM health_fitness.health_fitness_dataset; -- 2024-01-01 to 2024-12-12

SELECT
  ROUND(AVG(daily_steps)) AS avg_steps, ROUND(AVG(sleep_hours), 1) AS avg_sleep_hours,
  ROUND(AVG(stress_level), 1) AS avg_stress_level
FROM health_fitness.health_fitness_dataset;
-- avg_steps 8628 | avg_sleep_hours 7.0 | avg_stress_level 5.5
-- (calories_burned deliberately excluded here — it's session-level,
-- see the corrected query below, not a daily figure comparable to
-- FitBit's avg_calories.)

-- calories_burned is per logged exercise event (duration_minutes,
-- intensity, activity_type describe ONE session, not the day) —
-- re-analyzed accordingly, not as a daily total.
SELECT
  activity_type, intensity, COUNT(*) AS n_sessions,
  ROUND(AVG(duration_minutes), 1) AS avg_duration_min,
  ROUND(AVG(calories_burned), 1) AS avg_calories_per_session
FROM health_fitness.health_fitness_dataset
GROUP BY activity_type, intensity
ORDER BY activity_type, intensity;

-- Hydration — the reason this dataset was sourced (Spring angle).
SELECT gender, COUNT(*) AS n, ROUND(AVG(hydration_level), 2) AS avg_daily_water_liters
FROM health_fitness.health_fitness_dataset
GROUP BY gender ORDER BY gender;
-- F 2.50 | M 2.50 | Other 2.49 — no meaningful gender difference.


-- ================================================================
-- sleep_tracking.smartwatch_sleep_dataset
-- ================================================================
SELECT COUNT(*) FROM sleep_tracking.smartwatch_sleep_dataset; -- 19978
SELECT COUNT(DISTINCT user_id) FROM sleep_tracking.smartwatch_sleep_dataset;

SELECT
  ROUND(AVG(step_count_day)) AS avg_daily_steps,
  ROUND(AVG(duration_minutes) / 60.0, 1) AS avg_sleep_hours,
  ROUND(AVG(stress_score), 1) AS avg_stress
FROM sleep_tracking.smartwatch_sleep_dataset;
-- avg_daily_steps 6048 | avg_sleep_hours 7.5 | avg_stress 34.8
-- Note: stress_score here isn't on a confirmed comparable scale to
-- health_fitness_dataset's stress_level (avg 5.5) — don't compare directly.


WITH ActivityBuckets AS (
    SELECT 
        user_id,
        date_recorded,
        duration_minutes / 60.0 AS sleep_hours,
        sleep_efficiency_pct, 
        step_count_day,
        CASE 
            WHEN step_count_day < 5000 THEN '1. Sedentary'
            WHEN step_count_day BETWEEN 5000 AND 7499 THEN '2. Low Active'
            WHEN step_count_day BETWEEN 7500 AND 9999 THEN '3. Somewhat Active'
            WHEN step_count_day >= 10000 THEN '4. Highly Active'
        END AS activity_level
    FROM 
        sleep_tracking.smartwatch_sleep_dataset
)
SELECT 
    activity_level,
    COUNT(user_id) AS total_sessions,
    ROUND(AVG(sleep_hours), 2) AS avg_sleep_hours,
    ROUND(AVG(sleep_efficiency_pct), 2) AS avg_sleep_efficiency
FROM 
    ActivityBuckets
WHERE 
    activity_level IS NOT NULL
GROUP BY 
    activity_level
ORDER BY 
    activity_level;


-- 1. Sedentary	7805	7.45	93.34
-- 2. Low Active	5477	7.55	93.24
-- 3. Somewhat Active	4203	7.48	93.49
-- 4. Highly Active	2493	7.49	93.15

-- ================================================================
-- Deeper analysis — segments and relationships, not just averages
-- ================================================================

-- Activity segments (dailyactivity_merged) — reveals the average
-- hides a skewed population, not a normal spread.
WITH segments AS (
  SELECT CASE
    WHEN totalsteps < 5000  THEN '1. Sedentary (<5k)'
    WHEN totalsteps < 7500  THEN '2. Low Active (5k-7.5k)'
    WHEN totalsteps < 10000 THEN '3. Somewhat Active (7.5k-10k)'
    WHEN totalsteps < 12500 THEN '4. Active (10k-12.5k)'
    ELSE '5. Highly Active (12.5k+)'
  END AS activity_segment
  FROM fitbit.dailyactivity_merged
)
SELECT activity_segment, COUNT(*) AS n_days,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_days
FROM segments GROUP BY activity_segment ORDER BY activity_segment;
-- Sedentary 483 (35.2%) | Low Active 249 (18.1%) | Somewhat Active 211 (15.4%)
-- | Active 231 (16.8%) | Highly Active 199 (14.5%)
-- Sedentary is by far the largest single segment — more than double
-- any other band.

-- Weekday vs. weekend (dailyactivity_merged)
SELECT
  CASE WHEN EXTRACT(DOW FROM activitydate) IN (0,6) THEN 'Weekend' ELSE 'Weekday' END AS day_type,
  ROUND(AVG(totalsteps)) AS avg_steps, ROUND(AVG(sedentaryminutes)) AS avg_sedentary_min
FROM fitbit.dailyactivity_merged GROUP BY day_type;
-- Weekday: 7427 steps, 1010 sedentary min | Weekend: 7188 steps, 984 sedentary min
-- ~3% difference either way — essentially flat, no strong weekday/weekend pattern.

-- Sedentary time vs. sleep quality — legitimate join, same FitBit
-- users, same dates, both tables.
SELECT
  CASE WHEN d.sedentaryminutes < 1000 THEN 'Lower sedentary (<1000 min)' ELSE 'Higher sedentary (1000+ min)' END AS sedentary_group,
  COUNT(*) AS n,
  ROUND(AVG(s.totalminutesasleep) / 60.0, 1) AS avg_hours_asleep,
  ROUND(AVG(100.0 * s.totalminutesasleep / NULLIF(s.totaltimeinbed, 0)), 1) AS avg_sleep_efficiency
FROM fitbit.dailyactivity_merged d
JOIN fitbit.sleepday_merged s ON d.id = s.id AND d.activitydate = s.sleepday
GROUP BY sedentary_group;
-- Lower sedentary: n=388, 7.2 hrs asleep, 91.5% efficiency
-- Higher sedentary: n=22, 2.6 hrs asleep, 93.4% efficiency
-- CAUTION: higher-sedentary group is only 22 nights (5.4% of sleep
-- data) — too small to treat as a reliable finding despite the size
-- of the gap. Flag as a lead, not a conclusion.

-- Steps vs. stress (health_fitness_dataset)
WITH buckets AS (
  SELECT stress_level,
    CASE WHEN daily_steps < 5000 THEN 'Under 5k' WHEN daily_steps < 10000 THEN '5k-10k' ELSE '10k+' END AS step_bucket
  FROM health_fitness.health_fitness_dataset WHERE daily_steps IS NOT NULL
)
SELECT step_bucket, COUNT(*) AS n, ROUND(AVG(stress_level), 2) AS avg_stress
FROM buckets GROUP BY step_bucket ORDER BY step_bucket;
-- 10k+: 5.47 | 5k-10k: 5.47 | Under 5k: 5.48 — flat, no relationship.

-- Hydration vs. intensity (health_fitness_dataset) — checking the
-- Spring angle on a different axis after gender showed nothing.
SELECT intensity, COUNT(*) AS n, ROUND(AVG(hydration_level), 2) AS avg_hydration_liters
FROM health_fitness.health_fitness_dataset GROUP BY intensity ORDER BY intensity;
-- High: 2.50 | Low: 2.50 | Medium: 2.50 — flat, no relationship.

-- Age brackets (health_fitness_dataset)
SELECT
  CASE WHEN age < 25 THEN '18-24' WHEN age < 35 THEN '25-34' WHEN age < 45 THEN '35-44'
       WHEN age < 55 THEN '45-54' ELSE '55-65' END AS age_bracket,
  COUNT(DISTINCT participant_id) AS n,
  ROUND(AVG(daily_steps)) AS avg_steps, ROUND(AVG(stress_level), 1) AS avg_stress
FROM health_fitness.health_fitness_dataset GROUP BY age_bracket ORDER BY age_bracket;
-- 18-24: n=446, 8632 steps, 5.5 stress
-- 25-34: n=592, 8622 steps, 5.5 stress
-- 35-44: n=634, 8631 steps, 5.5 stress
-- 45-54: n=647, 8633 steps, 5.5 stress
-- 55-65: n=681, 8625 steps, 5.5 stress
-- Flat across every bracket. Combined with the stress/hydration
-- flatness above: this dataset shows essentially no variation across
-- 5 independent segmentations (activity, gender, intensity, age x2).
-- Consistent with the ROCCC "likely synthetic" flag from Prepare —
-- treat this dataset's averages as rough context only, not as a
-- source for any segmented marketing claim.


-- ================================================================
-- EXPORT — run with: psql -U bellabeat_user -d bellabeat_db -h localhost -f sql/02_analysis.sql
-- Create folders first: mkdir -p data/clean/fitbit data/clean/health_fitness data/clean/sleep_tracking
-- ================================================================
\COPY fitbit.dailyactivity_merged TO 'data/clean/fitbit/dailyactivity_merged.csv' CSV HEADER
\COPY fitbit.sleepday_merged TO 'data/clean/fitbit/sleepday_merged.csv' CSV HEADER
\COPY fitbit.hourlysteps_merged TO 'data/clean/fitbit/hourlysteps_merged.csv' CSV HEADER
\COPY fitbit.hourlyintensities_merged TO 'data/clean/fitbit/hourlyintensities_merged.csv' CSV HEADER
\COPY (SELECT id, DATE(time) AS day, ROUND(AVG(value)) AS avg_hr, MIN(value) AS min_hr, MAX(value) AS max_hr FROM fitbit.heartrate_seconds_merged GROUP BY id, DATE(time)) TO 'data/clean/fitbit/heartrate_daily_agg.csv' CSV HEADER
\COPY sleep_tracking.smartwatch_sleep_dataset TO 'data/clean/sleep_tracking/smartwatch_sleep_dataset.csv' CSV HEADER
\COPY health_fitness.health_fitness_dataset TO 'data/clean/health_fitness/health_fitness_dataset.csv' CSV HEADER
