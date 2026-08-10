"""
Bellabeat Case Study — Chart Generation
Reads the CSVs exported by sql/02_analysis.sql and builds the 6 charts
listed in the README's Share section. Run from the project root:

    python scripts/generate_charts.py

Requires: pandas, matplotlib, seaborn (pip install pandas matplotlib seaborn)
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path

sns.set_theme(style="whitegrid")

CLEAN_DIR = Path("data/clean")
OUTPUT_DIR = Path("output")
OUTPUT_DIR.mkdir(exist_ok=True)


def load_data():
    return {
        "daily_activity": pd.read_csv(CLEAN_DIR / "fitbit" / "dailyactivity_merged.csv"),
        "sleepday": pd.read_csv(CLEAN_DIR / "fitbit" / "sleepday_merged.csv"),
        "hourly_steps": pd.read_csv(CLEAN_DIR / "fitbit" / "hourlysteps_merged.csv"),
        "smartwatch": pd.read_csv(CLEAN_DIR / "sleep_tracking" / "smartwatch_sleep_dataset.csv"),
        "health_fitness": pd.read_csv(CLEAN_DIR / "health_fitness" / "health_fitness_dataset.csv"),
    }


def chart_1_activity_segments(data):
    """The sedentary-heavy population, not a normal spread."""
    steps = data["daily_activity"]["totalsteps"]
    bins = [-1, 4999, 7499, 9999, 12499, steps.max()]
    labels = ["Sedentary\n(<5k)", "Low Active\n(5k-7.5k)", "Somewhat Active\n(7.5k-10k)",
              "Active\n(10k-12.5k)", "Highly Active\n(12.5k+)"]
    segment = pd.cut(steps, bins=bins, labels=labels)
    counts = segment.value_counts().reindex(labels)
    pct = 100 * counts / counts.sum()

    fig, ax = plt.subplots(figsize=(9, 5))
    sns.barplot(x=labels, y=counts.values, hue=labels, palette="Blues_d", legend=False, ax=ax)
    for i, (c, p) in enumerate(zip(counts.values, pct.values)):
        ax.text(i, c + 5, f"{c}\n({p:.1f}%)", ha="center", fontweight="bold")
    ax.set_ylabel("Number of days")
    ax.set_title("Activity Segments — FitBit (1,373 days, 35 users)")
    fig.tight_layout()
    fig.savefig(OUTPUT_DIR / "01_activity_segments.png", dpi=150)
    plt.close(fig)


def chart_2_weekday_vs_weekend(data):
    """Avg steps and sedentary minutes, weekday vs. weekend."""
    df = data["daily_activity"].copy()
    df["activitydate"] = pd.to_datetime(df["activitydate"])
    df["day_type"] = df["activitydate"].dt.dayofweek.apply(lambda d: "Weekend" if d >= 5 else "Weekday")
    summary = df.groupby("day_type")[["totalsteps", "sedentaryminutes"]].mean()

    fig, axes = plt.subplots(1, 2, figsize=(10, 5))
    sns.barplot(x=summary.index, y=summary["totalsteps"], hue=summary.index,
                palette="Blues_d", legend=False, ax=axes[0])
    axes[0].set_title("Avg Steps")
    axes[0].set_ylabel("Steps")
    for i, v in enumerate(summary["totalsteps"]):
        axes[0].text(i, v + 30, f"{v:,.0f}", ha="center", fontweight="bold")

    sns.barplot(x=summary.index, y=summary["sedentaryminutes"], hue=summary.index,
                palette="Oranges_d", legend=False, ax=axes[1])
    axes[1].set_title("Avg Sedentary Minutes")
    axes[1].set_ylabel("Minutes")
    for i, v in enumerate(summary["sedentaryminutes"]):
        axes[1].text(i, v + 5, f"{v:,.0f}", ha="center", fontweight="bold")

    fig.suptitle("Weekday vs. Weekend — essentially flat", fontsize=12)
    fig.tight_layout()
    fig.savefig(OUTPUT_DIR / "02_weekday_vs_weekend.png", dpi=150)
    plt.close(fig)


def chart_3_steps_by_hour(data):
    """The real timing signal — average steps by hour of day."""
    hourly = data["hourly_steps"].copy()
    hourly["activityhour"] = pd.to_datetime(hourly["activityhour"], format="mixed")
    hourly["hour"] = hourly["activityhour"].dt.hour
    by_hour = hourly.groupby("hour")["steptotal"].mean().reindex(range(24))

    fig, ax = plt.subplots(figsize=(9, 5))
    sns.lineplot(x=by_hour.index, y=by_hour.values, marker="o", color="#4C72B0", ax=ax)
    ax.axvspan(12, 20, color="#4C72B0", alpha=0.08, label="Peak window (noon-8pm)")
    ax.set_xlabel("Hour of day")
    ax.set_ylabel("Average steps")
    ax.set_title("Average Steps by Hour of Day — FitBit")
    ax.set_xticks(range(0, 24, 2))
    ax.legend()
    fig.tight_layout()
    fig.savefig(OUTPUT_DIR / "03_steps_by_hour.png", dpi=150)
    plt.close(fig)


def chart_4_sleep_distribution(data):
    """Sleep duration distribution vs. the 7-hour recommendation."""
    hours_asleep = data["sleepday"]["totalminutesasleep"] / 60.0

    fig, ax = plt.subplots(figsize=(8, 5))
    sns.histplot(hours_asleep, bins=20, color="#55A868", ax=ax)
    ax.axvline(7, color="#C44E52", linestyle="--", linewidth=2, label="7-hour recommendation")
    ax.set_xlabel("Hours asleep")
    ax.set_ylabel("Number of nights")
    ax.set_title("Sleep Duration Distribution — FitBit (n=24 users, 44.1% under 7h)")
    ax.legend()
    fig.tight_layout()
    fig.savefig(OUTPUT_DIR / "04_sleep_distribution.png", dpi=150)
    plt.close(fig)


def chart_5_health_fitness_flatness(data):
    """2x2 panel showing the Health & Fitness dataset's lack of variation
    across four independent segmentations — the finding IS the flat line."""
    df = data["health_fitness"].copy()

    fig, axes = plt.subplots(2, 2, figsize=(11, 9))

    df["step_bucket"] = pd.cut(df["daily_steps"], bins=[-1, 4999, 9999, df["daily_steps"].max()],
                                labels=["Under 5k", "5k-10k", "10k+"])
    stress_by_steps = df.groupby("step_bucket", observed=True)["stress_level"].mean()
    sns.barplot(x=stress_by_steps.index, y=stress_by_steps.values, hue=stress_by_steps.index,
                palette="Purples_d", legend=False, ax=axes[0, 0])
    axes[0, 0].set_ylim(0, 10)
    axes[0, 0].set_title("Avg Stress by Step Bucket")
    axes[0, 0].set_ylabel("Stress (1-10)")

    hyd_by_gender = df.groupby("gender")["hydration_level"].mean()
    sns.barplot(x=hyd_by_gender.index, y=hyd_by_gender.values, hue=hyd_by_gender.index,
                palette="Blues_d", legend=False, ax=axes[0, 1])
    axes[0, 1].set_ylim(0, 4)
    axes[0, 1].set_title("Avg Hydration by Gender")
    axes[0, 1].set_ylabel("Liters/day")

    hyd_by_intensity = df.groupby("intensity")["hydration_level"].mean()
    order = [l for l in ["Low", "Medium", "High"] if l in hyd_by_intensity.index]
    sns.barplot(x=order, y=hyd_by_intensity.reindex(order).values, hue=order,
                palette="Greens_d", legend=False, ax=axes[1, 0])
    axes[1, 0].set_ylim(0, 4)
    axes[1, 0].set_title("Avg Hydration by Intensity")
    axes[1, 0].set_ylabel("Liters/day")

    df["age_bracket"] = pd.cut(df["age"], bins=[17, 24, 34, 44, 54, 65],
                                labels=["18-24", "25-34", "35-44", "45-54", "55-65"])
    steps_by_age = df.groupby("age_bracket", observed=True)["daily_steps"].mean()
    sns.barplot(x=steps_by_age.index, y=steps_by_age.values, hue=steps_by_age.index,
                palette="Oranges_d", legend=False, ax=axes[1, 1])
    axes[1, 1].set_ylim(0, 10000)
    axes[1, 1].set_title("Avg Steps by Age Bracket")
    axes[1, 1].set_ylabel("Steps")

    fig.suptitle("Health & Fitness Dataset: Flat Across Every Segment Tested", fontsize=13, y=1.00)
    fig.tight_layout()
    fig.savefig(OUTPUT_DIR / "05_health_fitness_flatness.png", dpi=150)
    plt.close(fig)


def chart_6_cross_dataset_comparison(data):
    """Avg daily steps and avg sleep hours, FitBit vs. Health & Fitness vs. Smartwatch Sleep."""
    avg_steps = {
        "FitBit": data["daily_activity"]["totalsteps"].mean(),
        "Health & Fitness": data["health_fitness"]["daily_steps"].mean(),
        "Smartwatch Sleep": data["smartwatch"]["step_count_day"].mean(),
    }
    avg_sleep_hours = {
        "FitBit": data["sleepday"]["totalminutesasleep"].mean() / 60.0,
        "Health & Fitness": data["health_fitness"]["sleep_hours"].mean(),
        "Smartwatch Sleep": data["smartwatch"]["duration_minutes"].mean() / 60.0,
    }

    datasets = list(avg_steps.keys())
    fig, axes = plt.subplots(1, 2, figsize=(11, 5))

    sns.barplot(x=datasets, y=[avg_steps[d] for d in datasets], hue=datasets,
                palette="Blues_d", legend=False, ax=axes[0])
    axes[0].set_title("Avg Daily Steps")
    axes[0].set_ylabel("Steps")
    for i, d in enumerate(datasets):
        axes[0].text(i, avg_steps[d] + 50, f"{avg_steps[d]:,.0f}", ha="center", fontweight="bold")

    sns.barplot(x=datasets, y=[avg_sleep_hours[d] for d in datasets], hue=datasets,
                palette="Greens_d", legend=False, ax=axes[1])
    axes[1].set_title("Avg Sleep Hours")
    axes[1].set_ylabel("Hours")
    for i, d in enumerate(datasets):
        axes[1].text(i, avg_sleep_hours[d] + 0.05, f"{avg_sleep_hours[d]:.1f}", ha="center", fontweight="bold")

    fig.suptitle("Cross-Dataset Comparison — compared side by side, not joined", fontsize=12)
    fig.tight_layout()
    fig.savefig(OUTPUT_DIR / "06_cross_dataset_comparison.png", dpi=150)
    plt.close(fig)


def main():
    data = load_data()
    chart_1_activity_segments(data)
    chart_2_weekday_vs_weekend(data)
    chart_3_steps_by_hour(data)
    chart_4_sleep_distribution(data)
    chart_5_health_fitness_flatness(data)
    chart_6_cross_dataset_comparison(data)
    print(f"6 charts saved to {OUTPUT_DIR}/")


if __name__ == "__main__":
    main()
