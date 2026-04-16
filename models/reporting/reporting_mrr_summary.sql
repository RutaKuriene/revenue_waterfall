with waterfall as (
    select * from {{ ref('reporting_mrr_waterfall') }}
),

pivoted as (
    select
        report_month,
        sum(case when movement_type = 'new' then mrr_change else 0 end) as new_mrr,
        sum(case when movement_type = 'expansion' then mrr_change else 0 end) as expansion_mrr,
        sum(case when movement_type = 'contraction' then mrr_change else 0 end) as contraction_mrr,
        sum(case when movement_type = 'churn' then mrr_change else 0 end) as churn_mrr,
        sum(case when movement_type = 'reactivation' then mrr_change else 0 end) as reactivation_mrr,
        sum(mrr_change) as net_mrr_change,

        sum(case when movement_type = 'new' then account_count else 0 end) as new_accounts,
        sum(case when movement_type = 'expansion' then account_count else 0 end) as expansion_accounts,
        sum(case when movement_type = 'contraction' then account_count else 0 end) as contraction_accounts,
        sum(case when movement_type = 'churn' then account_count else 0 end) as churn_accounts,
        sum(case when movement_type = 'reactivation' then account_count else 0 end) as reactivation_accounts
    from waterfall
    group by report_month
),

monthly_totals as (
    select
        account_id,
        report_month,
        sum(mrr_amount) as mrr
    from {{ ref('monthly_subscription_spine') }}
    group by account_id, report_month
),

ending_mrr as (
    select
        report_month,
        sum(mrr) as ending_mrr,
        count(distinct account_id) as active_accounts
    from monthly_totals
    group by report_month
)

select
    p.report_month,
    e.active_accounts,
    lag(e.ending_mrr) over (order by p.report_month) as beginning_mrr,
    p.new_mrr,
    p.expansion_mrr,
    p.reactivation_mrr,
    p.contraction_mrr,
    p.churn_mrr,
    p.net_mrr_change,
    e.ending_mrr,
    p.new_accounts,
    p.expansion_accounts,
    p.reactivation_accounts,
    p.contraction_accounts,
    p.churn_accounts,
    case
        when lag(e.ending_mrr) over (order by p.report_month) > 0
        then round(p.net_mrr_change / lag(e.ending_mrr) over (order by p.report_month) * 100, 2)
        else null
    end as net_mrr_growth_rate_pct,
    case
        when lag(e.ending_mrr) over (order by p.report_month) > 0
        then round(abs(p.churn_mrr) / lag(e.ending_mrr) over (order by p.report_month) * 100, 2)
        else null
    end as gross_mrr_churn_rate_pct
from pivoted p
left join ending_mrr e on p.report_month = e.report_month
order by p.report_month
