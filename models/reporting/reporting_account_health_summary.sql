select
    report_month,
    count(distinct account_id) as total_accounts,
    count_if(health_tier = 'healthy') as healthy_accounts,
    count_if(health_tier = 'at_risk') as at_risk_accounts,
    count_if(health_tier = 'critical') as critical_accounts,
    count_if(health_tier = 'no_activity') as no_activity_accounts,
    round(100.0 * count_if(health_tier = 'healthy') / nullif(count(distinct account_id), 0), 2) as pct_healthy,
    round(100.0 * count_if(health_tier = 'at_risk') / nullif(count(distinct account_id), 0), 2) as pct_at_risk,
    round(100.0 * count_if(health_tier = 'critical') / nullif(count(distinct account_id), 0), 2) as pct_critical,
    round(avg(health_score), 3) as avg_health_score,
    round(median(health_score), 3) as median_health_score,
    round(min(health_score), 3) as min_health_score,
    round(max(health_score), 3) as max_health_score
from {{ ref('fct_account_health_scorecard') }}
where health_score is not null
group by report_month
order by report_month