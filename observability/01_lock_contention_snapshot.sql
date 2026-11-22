-- Asynchronous lock contention capture for diagnosing peak-hour database slowdowns.
-- Intended to run out-of-band when application latency exceeds threshold,
-- persisting active WAIT locks into a dedicated log table for historical root-cause analysis.

INSERT INTO dbo.db_latency_lock_logs (
    captured_at,
    session_id,
    database_id,
    resource_type,
    request_mode,
    request_status,
    wait_duration_ms
)
SELECT
    SYSDATETIME()                  AS captured_at,
    tl.request_session_id          AS session_id,
    tl.resource_database_id        AS database_id,
    tl.resource_type               AS resource_type,
    tl.request_mode                AS request_mode,
    tl.request_status              AS request_status,
    COALESCE(er.wait_time, 0)      AS wait_duration_ms
FROM sys.dm_tran_locks AS tl WITH (NOLOCK)
LEFT JOIN sys.dm_exec_requests AS er WITH (NOLOCK)
    ON er.session_id = tl.request_session_id
WHERE tl.request_status = 'WAIT'
  AND tl.request_session_id <> @@SPID;
