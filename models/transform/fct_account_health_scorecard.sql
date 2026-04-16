with feature_usage_monthly as (
    select
        f.account_id,
        date_trunc('month', f.usage_date) as report_month,
        count(distinct f.usage_id) as feature_events,
        sum(f.usage_count) as total_usage_count,
        sum(f.error_count) as total_error_count,
        count_if(f.is_beta_feature) as beta_feature_events,
        round(sum(f.usage_duration_secs) / 60.0, 2) as total_usage_duration_mins
    from {{ ref('fct_feature_usage') }} f
    where f.account_id is not null
    group by f.account_id, date_trunc('month', f.usage_date)
),

support_tickets_monthly as (
    select
        s.account_id,
        s.ticket_month as report_month,
        count(distinct s.ticket_id) as support_tickets_count,
        round(avg(s.satisfaction_score), 2) as avg_satisfaction_score,
        count_if(s.escalation_flag) as escalation_count,
        count_if(s.satisfaction_score < 3) as low_satisfaction_tickets,
        round(avg(s.resolution_time_hours), 1) as avg_resolution_hours,
        max(s.resolution_speed_tier) as slowest_resolution_tier
    from {{ ref('fct_support_tickets') }} s
    where s.account_id is not null
    group by s.account_id, s.ticket_month
),

combined as (
    select
        coalesce(f.account_id, s.account_id) as account_id,
        coalesce(f.report_month, s.report_month) as report_month,
        coalesce(f.feature_events, 0) as feature_events,
        coalesce(f.total_usage_count, 0) as total_usage_count,
        coalesce(f.total_error_count, 0) as total_error_count,
        coalesce(f.beta_feature_events, 0) as beta_feature_events,
        coalesce(f.total_usage_duration_mins, 0) as total_usage_duration_mins,
        coalesce(s.support_tickets_count, 0) as support_tickets_count,
        coalesce(s.avg_satisfaction_score, null) as avg_satisfaction_score,
        coalesce(s.escalation_count, 0) as escalation_count,
        coalesce(s.low_satisfaction_tickets, 0) as low_satisfaction_tickets,
        coalesce(s.avg_resolution_hours, null) as avg_resolution_hours,
        coalesce(s.slowest_resolution_tier, null) as slowest_resolution_tier
    from feature_usage_monthly f
    full outer join support_tickets_monthly s
        on f.account_id = s.account_id
        and f.report_month = s.report_month
),

health_score_calc as (
    select
        account_id,
        report_month,
        feature_events,
        total_usage_count,
        total_error_count,
        beta_feature_events,
        total_usage_duration_mins,
        support_tickets_count,
        avg_satisfaction_score,
        escalation_count,
        low_satisfaction_tickets,
        avg_resolution_hours,
        slowest_resolution_tier,
        case
            when feature_events = 0 and support_tickets_count = 0 then null
            when feature_events = 0 then round(
                (coalesce(avg_satisfaction_score, 50) / 100.0) * 0.5
                + (1.0 / (1.0 + escalation_count)) * 0.5
                , 2)
            when support_tickets_count = 0 then round(
                (coalesce(total_usage_count, 0) / nullif(feature_events, 0)) / 100.0 * 0.5
                + (1.0 / (1.0 + total_error_count)) * 0.5
                , 2)
            else round(
                (coalesce(total_usage_count, 0) / nullif(feature_events, 0)) / 100.0 * 0.3
                + (1.0 / (1.0 + total_error_count)) * 0.3
                + (coalesce(avg_satisfaction_score, 50) / 100.0) * 0.2
                + (1.0 / (1.0 + escalation_count)) * 0.2
                , 2)
        end as health_score
    from combined
)

select
    account_id,
    report_month,
    feature_events,
    total_usage_count,
    total_error_count,
    beta_feature_events,
    total_usage_duration_mins,
    support_tickets_count,
    avg_satisfaction_score,
    escalation_count,
    low_satisfaction_tickets,
    avg_resolution_hours,
    slowest_resolution_tier,
    health_score,
    case
        when health_score >= 0.75 then 'healthy'
        when health_score >= 0.5 then 'at_risk'
        when health_score is not null then 'critical'
        else 'no_activity'
    end as health_tier
from health_score_calc
order by account_id, report_month