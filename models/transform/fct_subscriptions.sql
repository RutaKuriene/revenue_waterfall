with subscriptions as (
    select * from {{ ref('stg_subscriptions') }}
),

accounts as (
    select * from {{ ref('stg_accounts') }}
)

select
    s.subscription_id,
    s.account_id,
    a.account_name,
    a.industry,
    s.start_date,
    s.end_date,
    s.plan_tier,
    s.seats,
    s.mrr_amount,
    s.arr_amount,
    s.is_trial,
    s.upgrade_flag,
    s.downgrade_flag,
    s.churn_flag,
    s.billing_frequency,
    s.auto_renew_flag,
    s.is_active,
    datediff('day', s.start_date, coalesce(s.end_date, current_date())) as subscription_duration_days,
    case
        when s.is_trial then 'trial'
        when s.churn_flag then 'churned'
        when s.is_active then 'active'
        else 'inactive'
    end as subscription_status
from subscriptions s
left join accounts a on s.account_id = a.account_id
