-- Scheduled SQL Agent job health overview.
-- Uses ROW_NUMBER() over msdb.dbo.sysjobhistory (step_id = 0 = overall job outcome)
-- to return each enabled job's most recent execution status and duration.

WITH ranked_job_runs AS (
    SELECT
        j.job_id,
        j.name AS job_name,
        j.enabled,
        h.run_status,
        h.run_date,
        h.run_time,
        h.run_duration,
        h.message,
        ROW_NUMBER() OVER (
            PARTITION BY j.job_id
            ORDER BY h.run_date DESC, h.run_time DESC, h.instance_id DESC
        ) AS rn
    FROM msdb.dbo.sysjobs AS j WITH (NOLOCK)
    LEFT JOIN msdb.dbo.sysjobhistory AS h WITH (NOLOCK)
        ON h.job_id = j.job_id
       AND h.step_id = 0
)
SELECT
    r.job_name,
    r.enabled,
    CASE r.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In Progress'
        ELSE 'No History'
    END AS last_run_status,
    r.run_date,
    r.run_time,
    r.run_duration,
    r.message
FROM ranked_job_runs AS r
WHERE r.rn = 1
ORDER BY
    CASE WHEN r.run_status = 0 THEN 0 ELSE 1 END,
    r.job_name;
