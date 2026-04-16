with source as (
    select * from {{ source('raw', 'accounts') }}
)

select
    account_id,
    account_name,
    industry,
    country,
    signup_date,
    referral_source,
    plan_tier as initial_plan_tier,
    seats as initial_seats,
    is_trial,
    churn_flag
from source