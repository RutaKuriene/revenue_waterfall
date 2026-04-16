with tickets as (
    select * from {{ ref('stg_support_tickets') }}
)

select
    ticket_id,
    account_id,
    submitted_at,
    closed_at,
    resolution_time_hours,
    priority,
    first_response_time_minutes,
    satisfaction_score,
    escalation_flag,
    date_trunc('month', submitted_at) as ticket_month,
    case
        when resolution_time_hours <= 4 then 'fast'
        when resolution_time_hours <= 24 then 'normal'
        when resolution_time_hours <= 72 then 'slow'
        else 'very_slow'
    end as resolution_speed_tier
from tickets
