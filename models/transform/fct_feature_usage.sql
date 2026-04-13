with usage as (
    select * from {{ ref('stg_feature_usage') }}
),

subscriptions as (
    select subscription_id, account_id from {{ ref('stg_subscriptions') }}
)

select
    u.usage_id,
    u.subscription_id,
    s.account_id,
    u.usage_date,
    u.feature_name,
    u.usage_count,
    u.usage_duration_secs,
    round(u.usage_duration_secs / 60.0, 2) as usage_duration_mins,
    u.error_count,
    u.is_beta_feature
from usage u
left join subscriptions s on u.subscription_id = s.subscription_id
