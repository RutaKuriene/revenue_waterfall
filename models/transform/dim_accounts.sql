with accounts as (
    select * from {{ ref('stg_accounts') }}
),

churn_events as (
    select * from {{ ref('stg_churn_events') }}
),

subscriptions as (
    select * from {{ ref('stg_subscriptions') }}
),

account_subscription_summary as (
    select
        account_id,
        count(*) as total_subscriptions,
        sum(case when is_active then 1 else 0 end) as active_subscriptions,
        sum(mrr_amount) as total_mrr,
        min(start_date) as first_subscription_date,
        max(start_date) as latest_subscription_date,
        max(case when is_active then plan_tier end) as current_plan_tier,
        sum(case when upgrade_flag then 1 else 0 end) as total_upgrades,
        sum(case when downgrade_flag then 1 else 0 end) as total_downgrades
    from subscriptions
    group by account_id
),

account_churn_summary as (
    select
        account_id,
        count(*) as churn_event_count,
        max(churn_date) as last_churn_date,
        max(is_reactivation)::boolean as has_reactivation,
        listagg(distinct reason_code, ', ') as churn_reasons,
        sum(refund_amount_usd) as total_refund_amount
    from churn_events
    group by account_id
)

select
    a.account_id,
    a.account_name,
    a.industry,
    a.country,
    a.signup_date,
    a.referral_source,
    a.initial_plan_tier,
    a.initial_seats,
    a.is_trial,
    a.churn_flag,
    s.total_subscriptions,
    s.active_subscriptions,
    s.total_mrr as current_total_mrr,
    s.first_subscription_date,
    s.latest_subscription_date,
    s.current_plan_tier,
    s.total_upgrades,
    s.total_downgrades,
    c.churn_event_count,
    c.last_churn_date,
    c.has_reactivation,
    c.churn_reasons,
    c.total_refund_amount,
    datediff('day', a.signup_date, coalesce(c.last_churn_date, current_date())) as account_lifetime_days
from accounts a
left join account_subscription_summary s on a.account_id = s.account_id
left join account_churn_summary c on a.account_id = c.account_id
