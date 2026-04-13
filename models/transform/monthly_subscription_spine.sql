with subscriptions as (
    select * from {{ ref('stg_subscriptions') }}
    where is_trial = false
    and mrr_amount > 0
),

date_bounds as (
    select
        date_trunc('month', min(start_date)) as min_month,
        date_trunc('month', max(coalesce(end_date, current_date()))) as max_month
    from subscriptions
),

months as (
    select
        dateadd('month', row_number() over (order by seq4()) - 1, min_month) as month_start
    from date_bounds, table(generator(rowcount => 100))
    qualify month_start <= max_month
),

subscription_months as (
    select
        s.subscription_id,
        s.account_id,
        m.month_start as report_month,
        s.plan_tier,
        s.seats,
        s.mrr_amount,
        s.start_date,
        s.end_date,
        s.upgrade_flag,
        s.downgrade_flag,
        s.churn_flag,
        s.billing_frequency
    from subscriptions s
    cross join months m
    where m.month_start >= date_trunc('month', s.start_date)
      and m.month_start < date_trunc('month', coalesce(s.end_date, dateadd('month', 1, current_date())))
)

select
    subscription_id,
    account_id,
    report_month,
    plan_tier,
    seats,
    mrr_amount,
    start_date,
    end_date,
    upgrade_flag,
    downgrade_flag,
    churn_flag,
    billing_frequency
from subscription_months