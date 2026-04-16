with source as (
    select * from {{ source('raw', 'subscriptions') }}
)

select
    subscription_id,
    account_id,
    start_date,
    end_date,
    plan_tier,
    seats,
    mrr_amount,
    arr_amount,
    is_trial,
    upgrade_flag,
    downgrade_flag,
    churn_flag,
    billing_frequency,
    auto_renew_flag,
    case
        when end_date is null and is_trial = false then true
        else false
    end as is_active
from source
