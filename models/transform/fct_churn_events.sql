with churn as (
    select * from {{ ref('stg_churn_events') }}
),

accounts as (
    select account_id, industry, country, signup_date from {{ ref('stg_accounts') }}
)

select
    c.churn_event_id,
    c.account_id,
    a.industry,
    a.country,
    a.signup_date,
    c.churn_date,
    c.reason_code,
    c.refund_amount_usd,
    c.preceding_upgrade_flag,
    c.preceding_downgrade_flag,
    c.is_reactivation,
    c.feedback_text,
    date_trunc('month', c.churn_date) as churn_month,
    datediff('day', a.signup_date, c.churn_date) as days_to_churn
from churn c
left join accounts a on c.account_id = a.account_id
