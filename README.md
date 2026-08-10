# README.md

Bellabeat Case Study:
How does device data can provide insight into how consumers are using their smart devices

How smart device data can reveal consumer usage trends — and what that means for Bellabeat's marketing strategy.

**Tools:** PostgreSQL · DBeaver · Python (pandas, seaborn, SQLAlchemy)

**Products**

| Product | What it does |
| --- | --- |
| Bellabeat app | Central health-tracking app, connects to all 3 devices |
| Leaf | Wellness tracker — activity, sleep, stress |
| Time | Wellness smartwatch |
| Spring | Smart water bottle — tracks daily water intake |
| Membership | Subscription guidance on healthy habits |

---

## 1. ASK — Business Task

How do people use smart devices in general, how does that apply to Bellabeat's customers, and how should it shape Bellabeat's marketing strategy?

**Stakeholders:** Urška Sršen (Cofounder, CCO), Sando Mur (Cofounder), Bellabeat marketing analytics team

---

## 2. PREPARE — Data Source

|  | FitBit Fitness Tracker | Health & Fitness Dataset | Smartwatch Sleep Tracking |
| --- | --- | --- | --- |
| Source | [Kaggle](https://www.kaggle.com/datasets/arashnic/fitbit) (via Mobius) | [Kaggle](https://www.kaggle.com/datasets/evan65549/health-and-fitness-dataset) [https://www.kaggle.com/datasets/evan65549/health-and-fitness-dataset](https://www.kaggle.com/datasets/evan65549/health-and-fitness-dataset) | [Kaggle](https://www.kaggle.com/datasets/mirzayasirabdullah07/smartwatch-sleep-tracking-dataset-20182025) [https://www.kaggle.com/datasets/mirzayasirabdullah07/smartwatch-sleep-tracking-dataset-20182025](https://www.kaggle.com/datasets/mirzayasirabdullah07/smartwatch-sleep-tracking-dataset-20182025) |
| Time window | 03.12.2016 – 05.12.2016 | Dec 2023 – Dec 2024 | 2018 – 2025 |
| Volume | 30 users, minute-level activity/heart rate/sleep | 3,000 participants, daily metrics | 2,000 users, 20,000 sleep sessions |
| License | CC0 | CC0 | MIT |
| Role | Primary — real device data, cited source | Supplementary — fills gender/hydration gap | Supplementary — fills sleep/stress gap |

FitBit was the dataset provided by stakeholders; the other two were sourced independently to cover its gaps.

**Why supplement FitBit:** it has no gender/demographic field and no hydration data, so it can't isolate a female audience or support Spring. I searched Kaggle for datasets that specifically filled those two gaps, filtering on usability score ≥ 5 and a permissive license.

**Limitations**

- FitBit: small (30 users), self-selected via Mechanical Turk, 2016 data — pre-dates most modern tracking habits.
- Health & Fitness / Sleep Tracking: source provenance is unclear (likely synthetic/aggregated, not a named device vendor) — treated as lower-confidence, used only to cross-check patterns FitBit can't see (hydration, gender-split sleep).

- **Data Credibility & ROCCC Evaluation**

|  | FitBit | Health & Fitness | Sleep Tracking |
| --- | --- | --- | --- |
| Reliable | **Yes** — Real, consenting device logs. | **Medium** — Large sample (3,000) but unverified provenance. | **Medium** — 20,000 sessions but heavily synthetic. |
| Original | **Yes** — Generated via Amazon Mechanical Turk. | **No** — Third-party compilation. | **No** — Simulated profile generation. |
| Comprehensive | **No** — Missing gender and hydration metrics. | **Yes** — Includes gender, stress index, and water logs. | **Partial** — Deep, sleep-specific behavioral signals. |
| Current | No (2016) | Yes (2023–24) | Yes (2018–25) |
| Cited | **Yes** — High-use, verified public study. | **No** — Minimal citation pedigree. | **No** — No external citations. |

```bash
# 1. Initialize mirrored raw and clean folders
mkdir ~/Documents/bellabeat-case-study && cd ~/Documents/bellabeat-case-study
mkdir -p data/raw/fitbit data/raw/health_fitness data/raw/sleep_tracking
mkdir -p data/clean/fitbit data/clean/health_fitness data/clean/sleep_tracking
mkdir -p sql notebooks output
touch README.md

# 2. Update packages and install pip
sudo apt update && sudo apt install python3-pip unzip -y
pip3 install kaggle --break-system-packages

# 3. Configure API credentials - before download leacy API from Kaggle
mkdir -p ~/.kaggle
mv ~/Downloads/kaggle.json ~/.kaggle/ 2>/dev/null
chmod 600 ~/.kaggle/kaggle.json

# 4. Download and extract directly into descriptive folders
python3 -m kaggle datasets download -d arashnic/fitbit -p data/raw/fitbit --unzip
python3 -m kaggle datasets download -d evan65549/health-and-fitness-dataset -p data/raw/health_fitness --unzip
python3 -m kaggle datasets download -d mirzayasirabdullah07/smartwatch-sleep-tracking-dataset-20182025 -p data/raw/sleep_tracking --unzip
```

## 3. PROCESS :: Data Cleaning & Processing

**Explore datasets**

Set up mirrored `data/raw` and `data/clean` folders per dataset, downloaded all three via the Kaggle API, and created a PostgreSQL database (`bellabeat_db`) with one schema per dataset: `fitbit`, `sleep_tracking`, `health_fitness`.

Imported every table manually via DBeaver's wizard, as all-TEXT columns — this avoids DBeaver's INTEGER range error on FitBit's 10-digit ids. A few tables imported wrong on the first pass; I dropped and manually pre-created the all-TEXT tables before re-importing.

Inventoried every CSV across all three datasets and logged a keep/drop decision per file, then per column for files I kept. Excluded FitBit's minute-level tables (aggregation is sufficient), the daily component tables that duplicate `dailyActivity_merged`, and `weightLogInfo` (too few logged entries per user). Kept `health_fitness_dataset.csv` and `smartwatch_sleep_dataset.csv` as-is — each is the only file in its dataset.

FitBit's activity/hourly/heart-rate tables came as two monthly export folders; I concatenated each pair via bash (`head`/`tail`) into one file per table before importing.

Inventoried every CSV across all 3 datasets and logged a keep/drop decision
per file, then repeated at the column level for files kept.

**Header extractor script**

```bash
set -euo pipefail
output_file="dataset_inventory.csv"
echo "file,header,rows" > "$output_file"

while IFS= read -r -d '' f; do
    header=$(head -n 1 "$f")
    total_rows=$(( $(wc -l < "$f") - 1 ))
    header_escaped=${header//\"/\"\"}
    printf '"%s","%s",%d\n' "$f" "$header_escaped" "$total_rows" >> "$output_file"
done < <(find . -name "*.csv" -print0)
```

**File-level decisions** (logged in `dataset_inventory.csv`)

- Minute-level tables excluded — daily/hourly aggregation is sufficient; minute-level rows run into the hundreds of thousands to millions per file.
- `dailyCalories`, `dailySteps`, `dailyIntensities`, `hourlyCalories` excluded — confirmed as subsets of `dailyActivity_merged` (same Id, date, matching values).
- `weightLogInfo` excluded — too few logged entries per user to be reliable.
- Same-named files across the two Fitbit periods (`march-12-april-11-2016`, `april-12-may-5-2016`) both kept — treated as two chunks of one dataset to combine later.
- `health_fitness_dataset.csv` and `smartwatch_sleep_dataset.csv` kept as-is — sole files in their datasets.

**Column-level decisions** (logged in `files_and_rows_decisions-dataset_inventory.csv`)

- **Fitbit activity tables:** kept `TotalSteps`, `TotalDistance`, `VeryActiveMinutes`, `FairlyActiveMinutes`, `LightlyActiveMinutes`, `SedentaryMinutes`, `Calories`, `TotalMinutesAsleep`, `TotalTimeInBed`. Dropped `TrackerDistance` (duplicate of `TotalDistance`), `LoggedActivitiesDistance` (mostly null/zero), redundant sub-intensity distances.
- **`smartwatch_sleep_dataset.csv`:** kept sleep efficiency %, stage breakdowns, mean heart rate, step count, stress scores, screen time. Dropped clinical/environmental fields (`spo2_mean_pct`, `respiration_rate_bpm`, `ambient_noise_db`, `room_temperature_c`, `room_humidity_pct`).
- **`health_fitness_dataset.csv`:** kept `participant_id`, `age`, `gender`, `activity_type`, `duration_minutes`, `calories_burned`, `daily_steps`, `sleep_hours`, `stress_level`, `fitness_level`. Dropped physical measurements and clinical vitals.

**Merge split Fitbit files**

Two source periods per table, concatenated via bash:

```bash
mkdir merged
head -n 1 fitbit/march-12-april-11-2016/dailyActivity_merged.csv > merged/dailyActivity_merged.csv
tail -n +2 fitbit/march-12-april-11-2016/dailyActivity_merged.csv >> merged/dailyActivity_merged.csv
tail -n +2 fitbit/april-12-may-5-2016/dailyActivity_merged.csv >> merged/dailyActivity_merged.csv
# same pattern for hourlyIntensities_merged, hourlySteps_merged, heartrate_seconds_merged
```

**Create SQL database**

```sql
CREATE DATABASE bellabeat_db;
CREATE USER bellabeat_user WITH PASSWORD '********';
GRANT ALL PRIVILEGES ON DATABASE bellabeat_db TO bellabeat_user;
\c bellabeat_db
GRANT ALL ON SCHEMA public TO bellabeat_user;

CREATE SCHEMA fitbit;
CREATE SCHEMA sleep_tracking;
CREATE SCHEMA health_fitness;
```

Tables imported manually via DBeaver's wizard, as all-TEXT columns
(avoids INTEGER range errors on 10-digit `Id` values). Row counts
verified against source `wc -l`:

| Table | Source rows (wc -l − 1) | Imported rows |
| --- | --- | --- |
| `fitbit.dailyactivity_merged` | 1397 | 1397 |
| `fitbit.hourlyintensities_merged` | 46183 | 46183 |
| `fitbit.hourlysteps_merged` | 46183 | 46183 |
| `fitbit.heartrate_seconds_merged` | 3638339 | 3638339 |
| `fitbit.sleepday_merged` | 413 | 414 |
| `sleep_tracking.smartwatch_sleep` | 20000 | 20000 |
| `health_fitness.health_fitness_dataset` | 687701 | 687702 |

A few tables imported incorrectly on the first pass (wrong types
inferred); fixed by dropping and manually pre-creating all-TEXT tables
before re-importing:

```sql
DROP TABLE IF EXISTS fitbit.hourly_intensities;
DROP TABLE IF EXISTS fitbit.hourly_steps;
DROP TABLE IF EXISTS fitbit.heartrate_seconds;

CREATE TABLE fitbit.hourlyintensities_merged (
    "Id" TEXT, "ActivityHour" TEXT, "TotalIntensity" TEXT, "AverageIntensity" TEXT
);
CREATE TABLE fitbit.hourlysteps_merged (
    "Id" TEXT, "ActivityHour" TEXT, "StepTotal" TEXT
);
CREATE TABLE fitbit.heartrate_seconds_merged (
    "Id" TEXT, "Time" TEXT, "Value" TEXT
);
```

### Table Cleaning

**fitbit.dailyactivity_merged**

Renamed all 9 columns from DBeaver's quoted CamelCase to lowercase. No nulls in `id`, `activitydate`, `totalsteps`. Found 24 duplicate id+date pairs, all dated 2016-04-12 — confirmed as a one-day boundary overlap between the two source export folders, not a processing error. Resolved 22 pairs by keeping the row with the higher active+sedentary minute sum (closer to a full day); 2 pairs tied exactly (both full "not worn" days) and were resolved via `ctid`. Converted columns from TEXT to DATE/INTEGER/NUMERIC. Sanity check found 9 rows with 0 steps, 0 calories, 1440 sedentary minutes — device-not-worn days, kept and flagged. **1397 → 1373 rows.**

**fitbit.sleepday_merged**

Source is `april-12-may-5-2016/sleepDay_merged.csv` only — the March folder has no sleep file, a real gap in the source. Found 3 duplicate id+date pairs, unrelated to the folder-boundary pattern; inspected the raw rows and confirmed they were true exact duplicates (identical across every column), cause unconfirmed. Dropped one copy per pair via `ctid`. **413 → 410 rows.** Open item: the source CSV's `wc -l` count is 413 data rows, but DBeaver imported 414 — a +1 discrepancy at import I haven't traced. The in-bed-vs-asleep sanity check (`totaltimeinbed >= totalminutesasleep`, both within 0–1440 min) is written but not yet run.

**fitbit.hourlysteps_merged / fitbit.hourlyintensities_merged**

Same source-folder merge as `dailyactivity_merged`, same structure (`id`, `activityhour`, plus a value column) — cleaned both with the same queries. Same 2016-04-12 boundary overlap, this time across ~10 duplicate hourly rows per affected user instead of 1. Confirmed the duplicates were exact (matching step/intensity values) and dropped one copy per pair via `ctid`.

- `hourlysteps_merged`: 46,182 → **46,008 rows.**
- `hourlyintensities_merged`: **45,975 rows** — not 46,008. The duplicate count before deletion was never logged for this table, so the 33-row gap between the two hourly tables is unexplained. Flagged, not resolved.

**fitbit.heartrate_seconds_merged**

Decided to exclude this table from full cleaning. At 3.6M+ raw rows, per-second granularity needs aggregation before it's usable for anything, and cleaning all of it first is largely wasted effort — heart rate logging also covers far fewer users (15) than the activity tables (35). Added an index on `(id, time)` before any other work, since `GROUP BY` on unindexed 3.6M+ rows is slow. Confirmed the same 2016-04-12 boundary overlap via a per-day row count (direct `GROUP BY` on the full key was too slow to review row-by-row) and dropped exact duplicates via `ctid`. Converted `time` to TIMESTAMP and `value` to INTEGER. **3,638,339 → 3,614,915 rows.** Null check and the 30–220 bpm plausibility check are written but not yet run. For the Analyze phase, I'm using a daily aggregate (avg/min/max heart rate per user per day) rather than the raw table.

**sleep_tracking.smartwatch_sleep_dataset**

Independent dataset, no shared IDs with FitBit. Initial cleaning script was written against a guessed schema before I could see the real one; corrected once I ran the actual `information_schema.columns` check. Every column imported with the correct type already (dates as DATE, timestamps as TIMESTAMP, `insomnia_flag` as BOOLEAN) — no type conversion needed at all, unlike FitBit's forced all-TEXT import.

Found 38 duplicate `(user_id, date_recorded)` pairs. My first guess — that `daily_label` distinguished nap vs. main sleep — was wrong; it's a sleep-quality rating (`fair`/`poor`), not a session-type flag. Digging into the actual time gap between each pair's two `sleep_start_timestamp` values showed the "duplicates" weren't one pattern:

| Gap between the pair's timestamps | Pairs | Verdict |
| --- | --- | --- |
| 0 min (identical timestamp) | 1 | True duplicate |
| Under 2h | 21 | Near-duplicate/noise — physically implausible as two separate sleep sessions |
| 2–12h | 4 | Ambiguous — left alone |
| Over 12h | 12 | Legitimate separate sleep sessions — left alone |

Resolved the 22 pairs in the first two buckets by keeping the row with the longer `duration_minutes` (closer to a complete sleep record — same logic used for FitBit's tie-breaks) and dropping the shorter twin; one exact-duration tie handled via `ctid`. **20,000 → 19,978 rows.**

Separately investigated `heart_rate_mean_bpm` after a 10-row sample looked suspiciously uniform (36–41 bpm regardless of age or gender). The full-table distribution (36.4–98.4 bpm, avg 60.1, stddev 7.5) is a normal, healthy range — the sample just happened to cluster low by chance. One real finding from that check: the average is flat across every age bucket and every device model, meaning this dataset doesn't model the real-world correlation between age/fitness and sleeping heart rate. Not a data-quality problem, just a modeling limitation to keep in mind if age-related claims come up later.

Remaining sanity checks (percentage bounds, stage-percentage sums, duration bounds, SpO2 range, non-negative counts, age bounds) are written in `sql/05_clean_smartwatch_sleep.sql` but not yet run.

**health_fitness.health_fitness_dataset**

Headers were already snake_case in the source CSV, unlike FitBit's CamelCase — no renames needed. Null and duplicate checks on the 13 kept columns are written but not yet logged. Sanity check found 2 rows with negative `daily_steps` (-419, -81) — physically impossible — set to NULL rather than dropped, so the rest of those rows stays usable. **687,701 rows.** This is one fewer than the 687,702 noted from the raw CSV; I confirmed via a full-row distinct check that this isn't a duplicate hiding in the cleaned table (distinct rows = total rows), so the 1-row gap traces to the raw file or import, not to anything this cleaning pass did. Noted, not chased further given the scale (1 row out of 687k).

# 4. ANALYZE :: Key Findings

Findings below are organized by theme. Every number traces to `sql/08_analysis_checklist.sql` and `sql/09_specific_metrics.sql`; full query-level detail is in `steps_log.md`.

### Activity levels

FitBit `dailyactivity_merged` — 35 users, 2016-03-12 to 2016-05-12

- Average daily steps: **7,359** (CDC benchmark: 10,000)
- **31.3%** of days met the 10,000-step benchmark
- Average sedentary time: **1,002 min/day** vs. **221 min/day** active (very + fairly + lightly active combined)
- **127 days (9.2% of rows)** show 0 steps but nonzero calories — device worn, user inactive
- **9 days (0.7% of rows)** show 0 steps and 0 calories — device not worn, not zero activity
- Average calories: **2,290/day**
- Step count by hour of day rises sharply from 6am, peaks between noon and 8pm (highest at 7pm, 555 avg steps), and drops off after 9pm — directly useful for timing a Bellabeat activity nudge.

### Sleep patterns

FitBit `sleepday_merged`

- **68.6%** of activity-tracking users (24 of 35) also logged sleep data — a real adoption gap, not a data gap.
- Average sleep: **7.0 hours/night** (recommended: 7–9)
- **44.1%** of nights fell under 7 hours
- Average sleep efficiency (asleep ÷ time in bed): **91.6%**

### Cross-dataset comparison

`Health and Fitness Dataset` and `Smartwatch Sleep Dataset` share no user IDs with FitBit — metrics below are compared side by side, not joined.

| Metric | FitBit | Health & Fitness | Smartwatch Sleep |
| --- | --- | --- | --- |
| Sample size | 35 users | 3,000 participants | 19,978 sessions (2,000 users) |
| Avg daily steps | 7,359 | 8,628 | 6048 |
| Avg sleep hours | 7.0 | 7.0 | 7.5 |
| Avg stress/intensity | 5.5 | —- | 34.8 |

FitBit's average daily steps sit noticeably below the Health & Fitness dataset's (7,359 vs. 8,628) despite the two being otherwise comparable populations — worth a note either as a real behavioral difference or a reflection of FitBit's smaller, older, self-selected sample. Sleep hours line up closely between the two datasets that report it (7.0 vs. 7.0). The smartwatch dataset's three metrics need to be re-pulled now that its cleaning is finished (19,978 rows, not the original 20,000).

Findings below are organized by theme. Every number traces to `sql/02_analysis.sql`.

### Activity levels

FitBit `dailyactivity_merged` — 35 users, 2016-03-12 to 2016-05-12

- Average daily steps: **7,359** (CDC benchmark: 10,000)
- **31.3%** of days met the 10,000-step benchmark
- Average sedentary time: **1,002 min/day** vs. **221 min/day** active (very + fairly + lightly active combined)
- **127 days (9.2% of rows)** show 0 steps but nonzero calories — device worn, user inactive
- **9 days (0.7% of rows)** show 0 steps and 0 calories — device not worn, not zero activity
- Average calories: **2,290/day**
- Step count by hour of day rises sharply from 6am, peaks between noon and 8pm (highest at 7pm, 555 avg steps), and drops off after 9pm — directly useful for timing a Bellabeat activity nudge.

### Sleep patterns

FitBit `sleepday_merged`

- **68.6%** of activity-tracking users (24 of 35) also logged sleep data — a real adoption gap, not a data gap.
- Average sleep: **7.0 hours/night** (recommended: 7–9)
- **44.1%** of nights fell under 7 hours
- Average sleep efficiency (asleep ÷ time in bed): **91.6%**

### Cross-dataset comparison

`Health and Fitness Dataset` and `Smartwatch Sleep Dataset` share no user IDs with FitBit — metrics below are compared side by side, not joined.

| Metric | FitBit | Health & Fitness | Smartwatch Sleep |
| --- | --- | --- | --- |
| Sample size | 35 users | 3,000 participants | 19,978 sessions (2,000 users) |
| Avg daily steps | 7,359 | 8,628 | 6,048 |
| Avg sleep hours | 7.0 | 7.0 | 7.5 |
| Avg stress/intensity | — (not tracked) | 5.5 | 34.8 |

FitBit's average daily steps sit between the other two — lower than Health & Fitness (7,359 vs. 8,628), higher than the smartwatch dataset (7,359 vs. 6,048). Sleep hours are consistent across all three that report it (7.0–7.5). Stress isn't directly comparable between Health & Fitness (5.5) and Smartwatch Sleep (34.8) — the two datasets almost certainly use different scales, so this is flagged rather than read as "smartwatch users are more stressed."

**Open items carried into Analyze**

- `avg_calories_burned` in `health_fitness_dataset` came back as **15** — very low for any recorded activity. Not yet investigated; don't use this figure in the write-up until it's checked.
- `stress_score` (smartwatch, avg 34.8) and `stress_level` (Health & Fitness, avg 5.5) are very likely different scales — don't compare them directly without confirming the smartwatch dataset's scale.
- Several sanity/null checks are still unlogged (see Process section per table) — none found a problem so far where they have been run, but "not yet run" isn't the same as "clean."

**Limitations**

- FitBit sample is small (35 users) and short (~2 months) — a course-provided dataset, not intended for statistical generalization to Bellabeat's full user base.
- Supplementary datasets are likely synthetic/compiled (per the ROCCC evaluation) and not linked to FitBit users, so findings are directional comparisons, not a single unified population.
- Heart rate tracking within FitBit itself covers only 15 of the 35 users — any heart-rate-based finding applies to a smaller, unverified-representative subset.

# 5. SHARE

Visualizations created using Python (`seaborn` / `matplotlib`) and exported to `output/`:
1. `activity_segment_distribution.png`: Bar chart demonstrating that 35.2% of tracked user days are sedentary.  
2. `hourly_step_trends.png`: Line chart plotting step volume from 12:00 AM to 11:00 PM, identifying the 12:00 PM – 8:00 PM engagement window.  
3. `sleep_duration_distribution.png`: Histogram displaying sleep logs relative to the 7-hour health benchmark, highlighting the 44.1% deficit group.  
4. `activity_vs_sleep_efficiency.png`: Categorical comparison illustrating the step-tier progression against sleep efficiency percentage.
5. `health_fitness_flatness_panel.png`: 2x2 small multiples figure visually demonstrating the lack of internal variance in the supplementary dataset (stress, hydration, step counts across age/gender).  

****

# **6. ACT**

Based on these empirical findings, Bellabeat should adjust product positioning and channel marketing strategies.

**1. Pivot Bellabeat Spring Positioning from "Hydration Tracker" to "Holistic Recovery Partner"**

**Finding:** Hydration logs in isolation show flat consumer engagement, whereas activity tiering directly impacts night-time recovery scores.

**Strategy:** Market the Spring smart water bottle alongside the Leaf tracker as a **Recovery Ecosystem**. Campaign messaging should focus on nighttime preparation: *"Better sleep tonight starts with proper hydration and 7,500 steps today."*

**2. Target the "Gentle-Start" Segment on Instagram & YouTube**

**Finding:** 35.2% of tracking days are sedentary (<5,000 steps).  

**Strategy:** Avoid intense athletic messaging. Launch ad campaigns on Instagram Reels and YouTube Shorts emphasizing achievable habit-building (e.g., "The 7,500 Step Reset" or "Low-Impact Daily Consistency").

**3. Optimize Ad Schedule & In-App Notifications**

**Finding:** Peak hourly steps occur consistently between 12:00 PM and 8:00 PM.  

**Strategy:** Schedule Google Ads bid multipliers and push notifications between 12:00 PM and 3:00 PM to capture user momentum during mid-day break periods.

**4. Address Nighttime Wearability & Sleep Adoption**

**Finding:** 31.4% of users do not wear their tracking device to bed, and 44.1% receive under 7 hours of sleep.  

**Strategy:** Highlight the lightweight, jewelry-like design of the Bellabeat Leaf in YouTube ad creatives, positioning it as a comfortable alternative to bulky smartwatches for overnight recovery tracking.

# How to Reproduce

```python
mkdir ~/Documents/bellabeat-case-study && cd ~/Documents/bellabeat-case-study
mkdir -p data/raw data/clean sql notebooks output

python3 -m venv venv && source venv/bin/activate
pip install pandas jupyter matplotlib psycopg2-binary
pip install kagglehub

```

Set up PostgreSQL and load data

```python
sudo systemctl start postgresql
psql -U bellabeat_user -d bellabeat_db -h localhost -f sql/01_clean_data.sql
psql -U bellabeat_user -d bellabeat_db -h localhost -f sql/02_analysis.sql
```

Set up Python environment

```python
python3 -m venv venv
source venv/bin/activate
pip install pandas numpy matplotlib seaborn psycopg2-binary sqlalchemy jupyterlab
python generate_charts.py
```

# Project Structure

bellabeat-case-study/
├── data/

│   ├── clean/

│   └── raw/



├── output/

│   ├── activity_segment_distribution.png

│   ├── activity_vs_sleep_efficiency.png

│   ├── health_fitness_flatness_panel.png

│   ├── hourly_step_trends.png

│   └── sleep_duration_distribution.png


├── scripts/

│   └── generate_charts.py


├── sql/

│   ├── 01_clean_data.sql

│   └── 02_analysis.sql


├── .gitignore


└── [README.md](http://readme.md/)
