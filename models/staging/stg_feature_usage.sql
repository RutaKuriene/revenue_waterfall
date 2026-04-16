with source as (
    select
        *,
        row_number() over (partition by usage_id order by usage_date desc) as rn
    from {{ source('raw', 'feature_usage') }}
)

select
    usage_id,
    subscription_id,
    usage_date,
    feature_name,
    usage_count,
    usage_duration_secs,
    error_count,
    is_beta_feature
from source
where rn = 1
