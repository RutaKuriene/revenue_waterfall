-- Custom test: No subscription should have negative MRR in the monthly spine
-- This catches data quality issues upstream

select
    subscription_id,
    report_month,
    mrr_amount
from {{ ref('monthly_subscription_spine') }}
where mrr_amount < 0