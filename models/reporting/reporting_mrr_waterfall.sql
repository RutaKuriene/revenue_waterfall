with monthly_mrr as (
    select
        account_id,
        report_month,
        sum(mrr_amount) as mrr
    from {{ ref('monthly_subscription_spine') }}
    group by account_id, report_month
),

months as (
    select distinct report_month
    from monthly_mrr
),

current_month_mrr as (
    select
        m.report_month,
        mm.account_id,
        coalesce(mm.mrr, 0) as mrr
    from months m
    left join monthly_mrr mm on m.report_month = mm.report_month
),

previous_month_mrr as (
    select
        m.report_month,
        mm.account_id,
        coalesce(mm.mrr, 0) as mrr
    from months m
    left join monthly_mrr mm on mm.report_month = dateadd('month', -1, m.report_month)
),

combined as (
    select
        coalesce(c.report_month, p.report_month) as report_month,
        coalesce(c.account_id, p.account_id) as account_id,
        coalesce(c.mrr, 0) as current_mrr,
        coalesce(p.mrr, 0) as previous_mrr
    from current_month_mrr c
    full outer join previous_month_mrr p
        on c.report_month = p.report_month
        and c.account_id = p.account_id
    where coalesce(c.mrr, 0) != 0 or coalesce(p.mrr, 0) != 0
),

first_seen as (
    select
        account_id,
        min(report_month) as first_active_month
    from monthly_mrr
    group by account_id
),

classified as (
    select
        c.report_month,
        c.account_id,
        c.current_mrr,
        c.previous_mrr,
        c.current_mrr - c.previous_mrr as mrr_change,
        f.first_active_month,
        case
            when c.previous_mrr = 0 and c.current_mrr > 0 and c.report_month = f.first_active_month
                then 'new'
            when c.previous_mrr = 0 and c.current_mrr > 0 and c.report_month > f.first_active_month
                then 'reactivation'
            when c.previous_mrr > 0 and c.current_mrr = 0
                then 'churn'
            when c.current_mrr > c.previous_mrr and c.previous_mrr > 0
                then 'expansion'
            when c.current_mrr < c.previous_mrr and c.current_mrr > 0
                then 'contraction'
            else 'retained'
        end as movement_type
    from combined c
    left join first_seen f on c.account_id = f.account_id
    where c.current_mrr != c.previous_mrr
)

select
    report_month,
    movement_type,
    count(distinct account_id) as account_count,
    sum(mrr_change) as mrr_change
from classified
group by report_month, movement_type
order by report_month, movement_type
