-- Custom test: Ending MRR should equal Beginning MRR + Net MRR Change
-- This validates the fundamental waterfall accounting identity.
-- We allow a small tolerance for floating point rounding.

with validation as (
    select
        report_month,
        beginning_mrr,
        net_mrr_change,
        ending_mrr,
        abs(ending_mrr - (beginning_mrr + net_mrr_change)) as discrepancy
    from {{ ref('reporting_mrr_summary') }}
    where beginning_mrr is not null
)

select *
from validation
where discrepancy > 1
