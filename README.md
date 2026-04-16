# Company X - MRR Waterfall dbt Project

## Overview

This dbt project transforms Company X's raw SaaS data into business-ready analytics tables, with a primary focus on building a **Monthly Revenue Waterfall** for the CFO.

## Architecture

```
raw (source)          -> DATABASE.RAW.*
staging (views)       -> DATABASE.ANALYTICS_STAGING.*
transform (tables)    -> DATABASE.ANALYTICS_TRANSFORM.*
reporting (tables)    -> DATABASE.ANALYTICS_REPORTING.*
```

### Layer Descriptions

| Layer | Purpose | Materialization |
|-------|---------|-----------------|
| **Sources** | Raw CSV data loaded into `RAW` schema | N/A |
| **Staging** | 1:1 with sources, light renaming, type casting, deduplication | Views |
| **Transform** | Business logic, joins, enrichment. Fact & dimension tables | Tables |
| **Reporting** | Analyst-facing models optimized for consumption | Tables |

## Key Models

### `reporting_mrr_waterfall`
The core waterfall model. Classifies monthly MRR movements into:

| Movement Type | Definition |
|---------------|------------|
| **New** | First month an account ever generates MRR |
| **Expansion** | Account's MRR increased vs. prior month |
| **Contraction** | Account's MRR decreased vs. prior month (but didn't churn) |
| **Churn** | Account has a non-reactivation churn event in the month (from `churn_events`) and MRR decreased vs. prior month |
| **Reactivation** | Account returns after a gap in MRR (previously had revenue, left, came back) |

### `reporting_mrr_summary`
Pivoted summary table - one row per month with beginning MRR, each movement bucket, ending MRR, and SaaS metrics (growth rate, churn rate).

### `monthly_subscription_spine`
Intermediate model that "explodes" each subscription into one row per active month. Excludes trials and $0 MRR subscriptions. This is the foundation for waterfall calculations.


### `reporting_account_health_summary`
Monthly aggregate health population metrics. Tracks the distribution of accounts across health tiers (healthy, at_risk, critical, no_activity) with percentiles and central tendency. Enables executive dashboards showing overall account population health trends and early warning signals when critical tiers grow.

### `fct_account_health_scorecard` (Transform Layer)
Account-month grain health scorecard combining feature usage and support ticket signals. Serves as the fact table for behavioral health data and enables churn prediction, risk segmentation, and root-cause analysis. Join to `fct_churn_events` on (account_id, report_month) to correlate health scores with actual churn events.
## Modeling Decisions & Assumptions

1. **Trial exclusion**: Subscriptions where `is_trial = TRUE` or `mrr_amount = 0` are excluded from the MRR waterfall, as are considered not contributing to real revenue.

2. **MRR aggregation at account level**: The waterfall aggregates MRR per account per month (not per subscription). An account with multiple subscriptions has its MRR summed.

3. **Churn detection**: Churn is event-driven. The waterfall classifies churn using `churn_events` (via `fct_churn_events`), excluding reactivation events, and only when account MRR decreases vs. prior month.

4. **Churn-event deduplication for waterfall**: Churn events are deduplicated to one record per account per churn month before classification to avoid inflating account counts from duplicate source events.

5. **Reactivation vs. New**: An account's first-ever MRR month is "new." If it churns and later returns, that return is "reactivation." This is determined by checking if the account had any earlier MRR months.

6. **Month spine generation**: Uses a date spine from the earliest subscription start to the latest subscription end (or current date). Subscriptions are active from their start month through the month *before* their end date.

7. **Retained accounts**: Accounts with no MRR change are classified as "retained" but excluded from the waterfall output since they represent no movement.

8. **Source deduplication**: The `feature_usage` source contains duplicate `usage_id` values. The staging model deduplicates using `ROW_NUMBER()`, keeping the most recent record per `usage_id`.

## Data Quality

### Generic Tests (44 total, via schema.yml)
- `unique` and `not_null` on all primary keys across all layers
- `accepted_values` on categorical fields (plan_tier, priority, movement_type, billing_frequency, etc.)
- `relationships` tests for foreign keys (subscriptions -> accounts, churn_events -> accounts)

### Custom Business Logic Tests
- **`assert_mrr_waterfall_balances`**: Validates that `ending_mrr = beginning_mrr + net_mrr_change` for every month (within $1 tolerance).
- **`assert_no_negative_mrr_in_spine`**: Ensures no subscription contributes negative MRR to the spine.

## Setup Instructions

### Prerequisites
- Snowflake account
- A database with the following schemas: `RAW`, `ANALYTICS_STAGING`, `ANALYTICS_TRANSFORM`, `ANALYTICS_REPORTING`
- dbt Core 1.9+ with the Snowflake adapter (`dbt-snowflake`)

### 1. Clone and Configure

```bash
git clone <repo-url>
cd revenue_waterfall

# Create your profiles.yml from the example
cp profiles.yml.example profiles.yml
# Edit profiles.yml with your Snowflake credentials
```

### 2. Load Source Data

Load the 5 CSV files from the `data/` directory into your `RAW` schema. You can use Snowflake's `COPY INTO` command, the Snowflake web UI, or any loader of your choice:

```sql
-- Create schemas
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS ANALYTICS_STAGING;
CREATE SCHEMA IF NOT EXISTS ANALYTICS_TRANSFORM;
CREATE SCHEMA IF NOT EXISTS ANALYTICS_REPORTING;

-- Create a stage and load CSVs
CREATE OR REPLACE STAGE RAW.CSV_STAGE;
PUT file://data/accounts.csv @RAW.CSV_STAGE;
PUT file://data/subscriptions.csv @RAW.CSV_STAGE;
PUT file://data/feature_usage.csv @RAW.CSV_STAGE;
PUT file://data/support_tickets.csv @RAW.CSV_STAGE;
PUT file://data/churn_events.csv @RAW.CSV_STAGE;

-- Then COPY INTO each table 
```

### 3. Run the Project

```bash
dbt deps          # Install packages (if any)
dbt build         # Run models + tests in dependency order
```

### 4. Verify

```bash
dbt test          # Should show 44/44 PASS
```

Query the output:
```sql
SELECT * FROM ANALYTICS_REPORTING.REPORTING_MRR_SUMMARY ORDER BY REPORT_MONTH;
```

## Project Structure

```
revenue_waterfall/
|-- dbt_project.yml
|-- profiles.yml.example      # Template (profiles.yml is gitignored)
|-- packages.yml
|-- README.md
|-- data/                     # Source CSV files
|   |-- accounts.csv
|   |-- subscriptions.csv
|   |-- feature_usage.csv
|   |-- support_tickets.csv
|   |-- churn_events.csv
|-- models/
|   |-- staging/              # 1:1 source wrappers (views)
|   |   |-- sources.yml
|   |   |-- schema.yml
|   |   |-- stg_accounts.sql
|   |   |-- stg_subscriptions.sql
|   |   |-- stg_feature_usage.sql
|   |   |-- stg_support_tickets.sql
|   |   |-- stg_churn_events.sql
|   |-- transform/            # Business logic (tables)
|   |   |-- schema.yml
|   |   |-- dim_accounts.sql
|   |   |-- fct_subscriptions.sql
|   |   |-- fct_feature_usage.sql
|   |   |-- fct_support_tickets.sql
|   |   |-- fct_churn_events.sql
|   |   |-- monthly_subscription_spine.sql
|   |-- reporting/            # Analyst-facing (tables)
|   |   |-- schema.yml
|   |   |-- reporting_mrr_waterfall.sql
|   |   |-- reporting_mrr_summary.sql
|   |   |-- reporting_account_health_scorecard.sql
|-- tests/                    # Custom singular tests
|   |-- assert_mrr_waterfall_balances.sql
|   |-- assert_no_negative_mrr_in_spine.sql
|-- macros/
|-- analyses/
|-- seeds/
|-- snapshots/
```

## Limitations & Edge Cases

1. **Overlapping subscriptions**: An account can have multiple active subscriptions in the same month. The waterfall sums them, which is correct for total account MRR but doesn't show per-subscription movements.

2. **Mid-month changes**: The model uses monthly granularity. Upgrades/downgrades within a month are captured only as net change.

3. **Annual billing**: Annual subscriptions with MRR > 0 are treated the same as monthly.

4. **No calendar table**: The month spine is generated dynamically. A production version should use a shared calendar/date dimension.

5. **Event timing dependence**: Churn month attribution depends on churn event timestamps. Late or missing events can shift churn classification across months.

## Future Improvements (Production Readiness)

### Scalability & Performance
- **Incremental models** for `monthly_subscription_spine` and `fct_feature_usage` (largest tables)
- **Cluster keys** on date columns for large scan queries
|   |   |-- reporting_account_health_summary.sql
|   |-- fct_account_health_scorecard.sql

### Data Freshness & Incremental Strategies
- **dbt source freshness** checks on the RAW tables
- **Snapshots** on `subscriptions` to capture SCD Type 2 plan/tier changes over time
- Incremental strategy: append-only for usage data, merge for subscription state

### Monitoring & Data Quality Alerting
- **dbt exposures** linking models to downstream BI dashboards
- Automated alerting on anomalous MRR churn spikes (>2 standard deviations)
- Elementary or re_data for historical test result tracking
- Slack/email notifications on test failures in CI/CD pipeline

## Churn Analysis & Root-Cause Enrichment

The project pairs churn events with behavioral signals via `fct_account_health_scorecard`:

**Pattern 1: Account-Level Churn Root-Cause (Churn Events + Health):**
```sql
select
  e.account_id,
  e.churn_month as report_month,
  e.churn_event_id,
  e.reason_code,
  h.health_score,
  h.health_tier,
  h.total_error_count,
  h.avg_satisfaction_score,
  h.escalation_count,
  h.total_usage_count
from ANALYTICS_TRANSFORM.FCT_CHURN_EVENTS e
left join ANALYTICS_TRANSFORM.FCT_ACCOUNT_HEALTH_SCORECARD h
  on e.account_id = h.account_id
  and e.churn_month = h.report_month
where coalesce(e.is_reactivation, false) = false
order by e.churn_month, h.health_score asc;
```

**Pattern 2: Population Health Trends + Waterfall:**
```sql
select
  s.report_month,
  s.total_accounts,
  s.healthy_accounts,
  s.at_risk_accounts,
  s.critical_accounts,
  s.avg_health_score,
  w.churn_mrr,
  w.contraction_mrr,
  (w.churn_mrr + w.contraction_mrr) as total_downside_mrr
from ANALYTICS_REPORTING.REPORTING_ACCOUNT_HEALTH_SUMMARY s
left join (
  select
    report_month,
    sum(case when movement_type = 'churn' then mrr_change else 0 end) as churn_mrr,
    sum(case when movement_type = 'contraction' then mrr_change else 0 end) as contraction_mrr
  from ANALYTICS_REPORTING.REPORTING_MRR_WATERFALL
  group by report_month
) w on s.report_month = w.report_month
order by s.report_month;
```

**Use Cases:**
- **Churn root-cause**: Identify if churn was driven by low engagement, high errors, poor support experience, or a combination.
- **Early warning**: Flag accounts with critical health scores in prior month to proactively reach out before churn event.
- **Contraction insights**: Aggregate prior-month health scores for accounts that downgrade to understand self-service vs support-driven patterns.
- **Expansion validation**: Spot accounts with upcoming expansion activities but critical health scores to prevent churn after growth.